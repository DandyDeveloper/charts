#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=e2e/scripts/lib.sh
. "$SCRIPT_DIR/../scripts/lib.sh"

if [ "${E2E_ENABLE_KIND_PARTITION:-true}" != "true" ]; then
  log "scenario skipped: kind network partition disabled"
  exit 0
fi

require_cmd docker

if ! kubectl config current-context | grep -q "kind-${E2E_KIND_CLUSTER_NAME}$"; then
  if [ "${E2E_REQUIRE_KIND_PARTITION:-false}" = "true" ]; then
    die "kind network partition requires current context kind-${E2E_KIND_CLUSTER_NAME}"
  fi
  log "scenario skipped: current context is not kind-${E2E_KIND_CLUSTER_NAME}"
  exit 0
fi

log "scenario: kind network partition split brain"
old_master="$(current_master)"
old_master_ip="$(kubectl_e2e get pod "$old_master" -o jsonpath='{.status.podIP}')"
old_uid="$(kubectl_e2e get pod "$old_master" -o jsonpath='{.metadata.uid}')"
log "isolating master pod $old_master at $old_master_ip"

nodes="$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')"
peer_ips="$(
  kubectl_e2e get pods -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.podIP}{"\n"}{end}' \
    | awk -v old="$old_master" '$1 != old && $2 != "" { print $2 }'
)"

cleanup_partition() {
  log "removing kind iptables partition rules"
  while IFS= read -r node; do
    [ -n "$node" ] || continue
    while IFS= read -r peer_ip; do
      [ -n "$peer_ip" ] || continue
      docker exec "$node" iptables -D FORWARD -s "$old_master_ip" -d "$peer_ip" -j DROP >/dev/null 2>&1 || true
      docker exec "$node" iptables -D FORWARD -s "$peer_ip" -d "$old_master_ip" -j DROP >/dev/null 2>&1 || true
    done <<EOF
$peer_ips
EOF
  done <<EOF
$nodes
EOF
}
trap cleanup_partition EXIT

while IFS= read -r node; do
  [ -n "$node" ] || continue
  while IFS= read -r peer_ip; do
    [ -n "$peer_ip" ] || continue
    docker exec "$node" iptables -I FORWARD -s "$old_master_ip" -d "$peer_ip" -j DROP
    docker exec "$node" iptables -I FORWARD -s "$peer_ip" -d "$old_master_ip" -j DROP
  done <<EOF
$peer_ips
EOF
done <<EOF
$nodes
EOF

wait_for_new_master_besides "$old_master" 120
wait_for_master_count_at_least 2 60

cleanup_partition
trap - EXIT

wait_for_single_master 240
wait_for_pod_ready "$old_master" 240
new_uid="$(kubectl_e2e get pod "$old_master" -o jsonpath='{.metadata.uid}' 2>/dev/null || true)"
if [ -n "$new_uid" ] && [ "$new_uid" != "$old_uid" ]; then
  log "isolated master pod was recreated during repair: old_uid=$old_uid new_uid=$new_uid"
else
  log "isolated master pod remained in place after repair"
fi
