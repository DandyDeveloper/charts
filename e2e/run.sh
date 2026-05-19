#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=e2e/scripts/lib.sh
. "$SCRIPT_DIR/scripts/lib.sh"

E2E_CREATE_KIND_CLUSTER="${E2E_CREATE_KIND_CLUSTER:-false}"
E2E_SKIP_INSTALL="${E2E_SKIP_INSTALL:-false}"
E2E_VALUES_FILE="${E2E_VALUES_FILE:-$ROOT_DIR/e2e/values.yaml}"
E2E_TIMEOUT="${E2E_TIMEOUT:-12m}"

cleanup_done=false

on_exit() {
  local status=$?
  if [ "$cleanup_done" != "true" ]; then
    "$ROOT_DIR/e2e/scripts/collect-artifacts.sh" || true
  fi
  exit "$status"
}
trap on_exit EXIT

require_cmd kubectl
require_cmd helm

mkdir -p "$E2E_ARTIFACT_DIR"
log "artifact directory: $E2E_ARTIFACT_DIR"

if [ "$E2E_CREATE_KIND_CLUSTER" = "true" ]; then
  require_cmd kind
  if [ -z "${KUBECONFIG:-}" ]; then
    export KUBECONFIG="$ROOT_DIR/.e2e/kubeconfig"
    mkdir -p "$(dirname "$KUBECONFIG")"
    log "using isolated kubeconfig: $KUBECONFIG"
  fi
  if ! kind get clusters | grep -qx "$E2E_KIND_CLUSTER_NAME"; then
    log "creating kind cluster $E2E_KIND_CLUSTER_NAME"
    kind_args=(create cluster --name "$E2E_KIND_CLUSTER_NAME" --config "$ROOT_DIR/e2e/kind/multi-node.yaml")
    if [ -n "${E2E_KIND_NODE_IMAGE:-}" ]; then
      kind_args+=(--image "$E2E_KIND_NODE_IMAGE")
    fi
    kind "${kind_args[@]}"
  fi
  kind export kubeconfig --name "$E2E_KIND_CLUSTER_NAME" --kubeconfig "$KUBECONFIG"
  kubectl config use-context "kind-$E2E_KIND_CLUSTER_NAME"
fi

if [ "$E2E_SKIP_INSTALL" != "true" ]; then
  log "installing chart release=$E2E_RELEASE namespace=$E2E_NAMESPACE"
  kubectl get namespace "$E2E_NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$E2E_NAMESPACE"
  helm upgrade --install "$E2E_RELEASE" "$ROOT_DIR" \
    --namespace "$E2E_NAMESPACE" \
    --values "$E2E_VALUES_FILE" \
    --wait \
    --timeout "$E2E_TIMEOUT"
fi

log "waiting for Redis StatefulSet and HAProxy Deployment"
kubectl_e2e rollout status "statefulset/$E2E_FULLNAME-server" --timeout="$E2E_TIMEOUT"
kubectl_e2e rollout status "deployment/$E2E_FULLNAME-haproxy" --timeout="$E2E_TIMEOUT"
kubectl_e2e wait --for=condition=Ready pod \
  -l "release=$E2E_RELEASE,app=$E2E_APP_NAME" \
  --timeout="$E2E_TIMEOUT"
kubectl_e2e wait --for=condition=Ready pod \
  -l "release=$E2E_RELEASE,app=$E2E_APP_NAME-haproxy" \
  --timeout="$E2E_TIMEOUT"

wait_for_single_master 180

log "starting availability workload phase"
reset_workload_keys
E2E_WORKLOAD_LOG_NAME="workload-availability.log"
start_workload

for scenario in "$ROOT_DIR"/e2e/scenarios/01-*.sh "$ROOT_DIR"/e2e/scenarios/02-*.sh; do
  log "running $(basename "$scenario")"
  "$scenario"
done

stop_workload
E2E_ALLOWED_FAILED_OPS=0
assert_workload
wait_for_single_master 180

log "starting destructive resilience workload phase"
reset_workload_keys
E2E_WORKLOAD_LOG_NAME="workload-resilience.log"
start_workload

for scenario in "$ROOT_DIR"/e2e/scenarios/03-*.sh "$ROOT_DIR"/e2e/scenarios/04-*.sh "$ROOT_DIR"/e2e/scenarios/05-*.sh; do
  log "running $(basename "$scenario")"
  "$scenario"
done

stop_workload
E2E_ALLOWED_FAILED_OPS="${E2E_RESILIENCE_ALLOWED_FAILED_OPS:-5}"
assert_workload
wait_for_single_master 180

"$ROOT_DIR/e2e/scripts/collect-artifacts.sh"
cleanup_done=true

log "manual e2e suite completed successfully"
