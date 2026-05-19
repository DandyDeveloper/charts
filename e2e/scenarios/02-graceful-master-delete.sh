#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=e2e/scripts/lib.sh
. "$SCRIPT_DIR/../scripts/lib.sh"

log "scenario: graceful master pod termination"
old_master="$(current_master)"
old_uid="$(kubectl_e2e get pod "$old_master" -o jsonpath='{.metadata.uid}')"
log "deleting master pod with normal grace period: $old_master"

kubectl_e2e delete pod "$old_master" --wait=false
wait_for_master_change "$old_master" 120
wait_for_pod_uid_change "$old_master" "$old_uid" 240
wait_for_single_master 120
