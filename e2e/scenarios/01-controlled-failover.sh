#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=e2e/scripts/lib.sh
. "$SCRIPT_DIR/../scripts/lib.sh"

log "scenario: controlled Sentinel failover"
old_master="$(current_master)"
log "current master before controlled failover: $old_master"

response="$(sentinel_failover "$old_master" | tr -d '\r')"
log "sentinel failover response: $response"
[ "$response" = "OK" ] || die "controlled failover failed: $response"

wait_for_master_change "$old_master" 120
wait_for_single_master 120
log "sentinel master after controlled failover: $(sentinel_master_addr)"
