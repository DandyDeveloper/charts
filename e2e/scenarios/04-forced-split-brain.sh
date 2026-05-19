#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=e2e/scripts/lib.sh
. "$SCRIPT_DIR/../scripts/lib.sh"

log "scenario: forced split brain repair"
rogue="$(current_replica)"
log "forcing replica to become a rogue master: $rogue"

kubectl_e2e exec "$rogue" -c redis -- redis-cli -p "$E2E_REDIS_PORT" REPLICAOF NO ONE
wait_for_master_count_at_least 2 30
wait_for_single_master 180
