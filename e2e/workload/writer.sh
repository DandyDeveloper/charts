#!/bin/sh
set -eu

HOST="${REDIS_HOST:?REDIS_HOST is required}"
PORT="${REDIS_PORT:-6379}"
KEY="${E2E_KEY:-e2e:counter}"
STOP_KEY="${E2E_STOP_KEY:-e2e:stop}"
INTERVAL="${E2E_INTERVAL_SECONDS:-0.1}"
RETRY_INTERVAL="${E2E_RETRY_INTERVAL_SECONDS:-0.2}"
OP_TIMEOUT="${E2E_OPERATION_TIMEOUT_SECONDS:-15}"
MAX_SECONDS="${E2E_MAX_SECONDS:-900}"

ok_ops=0
failed_ops=0
raw_errors=0
max_ack=0
last_ok_ts=0
longest_gap=0
started_at=$(date +%s)
deadline=$((started_at + MAX_SECONDS))

is_integer() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

redis_cmd() {
  redis-cli -h "$HOST" -p "$PORT" --raw "$@"
}

while [ "$(date +%s)" -lt "$deadline" ]; do
  stop_value="$(redis_cmd GET "$STOP_KEY" 2>/dev/null || true)"
  if [ "$stop_value" = "1" ]; then
    break
  fi

  op_start=$(date +%s)
  attempts=0
  while true; do
    set +e
    output="$(redis_cmd INCR "$KEY" 2>&1)"
    status=$?
    set -e
    now=$(date +%s)

    if [ "$status" -eq 0 ] && is_integer "$output"; then
      ok_ops=$((ok_ops + 1))
      if [ "$output" -gt "$max_ack" ]; then
        max_ack="$output"
      fi
      if [ "$last_ok_ts" -gt 0 ]; then
        gap=$((now - last_ok_ts))
        if [ "$gap" -gt "$longest_gap" ]; then
          longest_gap="$gap"
        fi
      fi
      last_ok_ts="$now"
      echo "ok ts=$now value=$output attempts=$attempts"
      break
    fi

    raw_errors=$((raw_errors + 1))
    attempts=$((attempts + 1))
    elapsed=$((now - op_start))
    if [ "$elapsed" -ge "$OP_TIMEOUT" ]; then
      failed_ops=$((failed_ops + 1))
      echo "failed ts=$now attempts=$attempts elapsed=${elapsed}s output=$(printf '%s' "$output" | tr '\n' ' ' | cut -c1-240)"
      break
    fi
    sleep "$RETRY_INTERVAL"
  done

  sleep "$INTERVAL"
done

ended_at=$(date +%s)
echo "summary ok_ops=$ok_ops failed_ops=$failed_ops raw_errors=$raw_errors max_ack=$max_ack longest_gap_seconds=$longest_gap runtime_seconds=$((ended_at - started_at))"
