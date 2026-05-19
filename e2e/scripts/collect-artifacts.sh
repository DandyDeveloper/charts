#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=e2e/scripts/lib.sh
. "$SCRIPT_DIR/lib.sh"

mkdir -p "$E2E_ARTIFACT_DIR"

log "collecting artifacts into $E2E_ARTIFACT_DIR"
kubectl get namespace "$E2E_NAMESPACE" -o yaml > "$E2E_ARTIFACT_DIR/namespace.yaml" 2>&1 || true
kubectl_e2e get all -o wide > "$E2E_ARTIFACT_DIR/get-all.txt" 2>&1 || true
kubectl_e2e get pods -o yaml > "$E2E_ARTIFACT_DIR/pods.yaml" 2>&1 || true
kubectl_e2e get events --sort-by=.lastTimestamp > "$E2E_ARTIFACT_DIR/events.txt" 2>&1 || true
kubectl_e2e describe pods > "$E2E_ARTIFACT_DIR/describe-pods.txt" 2>&1 || true
helm -n "$E2E_NAMESPACE" status "$E2E_RELEASE" > "$E2E_ARTIFACT_DIR/helm-status.txt" 2>&1 || true

while IFS= read -r pod; do
  [ -n "$pod" ] || continue
  for container in redis sentinel split-brain-fix haproxy writer; do
    if kubectl_e2e get pod "$pod" -o jsonpath="{.spec.containers[?(@.name==\"$container\")].name}" 2>/dev/null | grep -qx "$container"; then
      kubectl_e2e logs "$pod" -c "$container" > "$E2E_ARTIFACT_DIR/${pod}-${container}.log" 2>&1 || true
      kubectl_e2e logs "$pod" -c "$container" --previous > "$E2E_ARTIFACT_DIR/${pod}-${container}-previous.log" 2>&1 || true
    fi
  done
done < <(kubectl_e2e get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
