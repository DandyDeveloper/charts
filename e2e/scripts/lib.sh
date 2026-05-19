#!/usr/bin/env bash
set -euo pipefail

E2E_NAMESPACE="${E2E_NAMESPACE:-redis-ha-e2e}"
E2E_RELEASE="${E2E_RELEASE:-redis-ha-e2e}"
E2E_CHART_DIR="${E2E_CHART_DIR:-.}"
E2E_FULLNAME="${E2E_FULLNAME:-$E2E_RELEASE}"
E2E_APP_NAME="${E2E_APP_NAME:-redis-ha}"
E2E_MASTER_GROUP="${E2E_MASTER_GROUP:-mymaster}"
E2E_REDIS_PORT="${E2E_REDIS_PORT:-6379}"
E2E_SENTINEL_PORT="${E2E_SENTINEL_PORT:-26379}"
E2E_REPLICAS="${E2E_REPLICAS:-3}"
E2E_KIND_CLUSTER_NAME="${E2E_KIND_CLUSTER_NAME:-redis-ha-e2e}"
E2E_WORKLOAD_POD="${E2E_WORKLOAD_POD:-$E2E_FULLNAME-e2e-writer}"
E2E_WORKLOAD_CONFIGMAP="${E2E_WORKLOAD_CONFIGMAP:-$E2E_FULLNAME-e2e-writer}"
E2E_COUNTER_KEY="${E2E_COUNTER_KEY:-e2e:counter}"
E2E_STOP_KEY="${E2E_STOP_KEY:-e2e:stop}"
E2E_ARTIFACT_DIR="${E2E_ARTIFACT_DIR:-.e2e/artifacts/$(date +%Y%m%d-%H%M%S)}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

die() {
  log "ERROR: $*"
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

kubectl_e2e() {
  kubectl -n "$E2E_NAMESPACE" "$@"
}

redis_pods() {
  kubectl_e2e get pods \
    -l "release=$E2E_RELEASE,app=$E2E_APP_NAME" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
    | grep -- "-server-" \
    | sort
}

haproxy_service() {
  printf '%s-haproxy' "$E2E_FULLNAME"
}

run_redis_cli() {
  local pod
  pod="$(redis_pods | head -n1)"
  [ -n "$pod" ] || die "no Redis pod found"
  kubectl_e2e exec "$pod" -c redis -- redis-cli -h "$(haproxy_service)" -p "$E2E_REDIS_PORT" --raw "$@"
}

redis_role() {
  local pod="$1"
  kubectl_e2e exec "$pod" -c redis -- redis-cli -p "$E2E_REDIS_PORT" --raw INFO replication \
    | awk -F: '/^role:/ { gsub(/\r/, "", $2); print $2; exit }'
}

current_master() {
  local pod role
  while IFS= read -r pod; do
    [ -n "$pod" ] || continue
    role="$(redis_role "$pod" 2>/dev/null || true)"
    if [ "$role" = "master" ]; then
      printf '%s\n' "$pod"
      return 0
    fi
  done < <(redis_pods)
  return 1
}

current_replica() {
  local pod role
  while IFS= read -r pod; do
    [ -n "$pod" ] || continue
    role="$(redis_role "$pod" 2>/dev/null || true)"
    if [ "$role" = "slave" ]; then
      printf '%s\n' "$pod"
      return 0
    fi
  done < <(redis_pods)
  return 1
}

master_count() {
  local count=0 pod role
  while IFS= read -r pod; do
    [ -n "$pod" ] || continue
    role="$(redis_role "$pod" 2>/dev/null || true)"
    if [ "$role" = "master" ]; then
      count=$((count + 1))
    fi
  done < <(redis_pods)
  printf '%s\n' "$count"
}

assert_single_master() {
  local masters=() pod role unknown=0 seen=0
  while IFS= read -r pod; do
    [ -n "$pod" ] || continue
    seen=$((seen + 1))
    role="$(redis_role "$pod" 2>/dev/null || true)"
    log "role pod=$pod role=${role:-unknown}"
    case "$role" in
      master) masters+=("$pod") ;;
      slave) ;;
      *) unknown=$((unknown + 1)) ;;
    esac
  done < <(redis_pods)

  if [ "$seen" -ne "$E2E_REPLICAS" ] || [ "${#masters[@]}" -ne 1 ] || [ "$unknown" -ne 0 ]; then
    die "expected $E2E_REPLICAS Redis pods, exactly one master, and all pods reporting a known role; pods=$seen masters=${#masters[@]} unknown=$unknown (${masters[*]:-none})"
  fi
  log "single master verified: ${masters[0]}"
}

wait_for_single_master() {
  local timeout="${1:-120}" end
  end=$((SECONDS + timeout))
  until (assert_single_master) >/dev/null 2>&1; do
    if [ "$SECONDS" -ge "$end" ]; then
      assert_single_master
      return 1
    fi
    sleep 2
  done
  assert_single_master
}

wait_for_master_change() {
  local old_master="$1" timeout="${2:-120}" end master
  end=$((SECONDS + timeout))
  while [ "$SECONDS" -lt "$end" ]; do
    master="$(current_master 2>/dev/null || true)"
    if [ -n "$master" ] && [ "$master" != "$old_master" ]; then
      log "master changed old=$old_master new=$master"
      return 0
    fi
    sleep 2
  done
  die "master did not change from $old_master within ${timeout}s"
}

wait_for_new_master_besides() {
  local old_master="$1" timeout="${2:-120}" end pod role
  end=$((SECONDS + timeout))
  while [ "$SECONDS" -lt "$end" ]; do
    while IFS= read -r pod; do
      [ -n "$pod" ] || continue
      [ "$pod" != "$old_master" ] || continue
      role="$(redis_role "$pod" 2>/dev/null || true)"
      if [ "$role" = "master" ]; then
        log "new master observed old=$old_master new=$pod"
        return 0
      fi
    done < <(redis_pods)
    sleep 2
  done
  die "no pod other than $old_master became master within ${timeout}s"
}

wait_for_master_count_at_least() {
  local expected="$1" timeout="${2:-60}" end count
  end=$((SECONDS + timeout))
  while [ "$SECONDS" -lt "$end" ]; do
    count="$(master_count)"
    if [ "$count" -ge "$expected" ]; then
      log "observed $count Redis masters"
      return 0
    fi
    sleep 1
  done
  die "expected at least $expected Redis masters within ${timeout}s"
}

wait_for_pod_ready() {
  local pod="$1" timeout="${2:-180}"
  kubectl_e2e wait --for=condition=Ready "pod/$pod" --timeout="${timeout}s"
}

wait_for_pod_uid_change() {
  local pod="$1" old_uid="$2" timeout="${3:-180}" end new_uid phase
  end=$((SECONDS + timeout))
  while [ "$SECONDS" -lt "$end" ]; do
    new_uid="$(kubectl_e2e get pod "$pod" -o jsonpath='{.metadata.uid}' 2>/dev/null || true)"
    phase="$(kubectl_e2e get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    if [ -n "$new_uid" ] && [ "$new_uid" != "$old_uid" ] && [ "$phase" = "Running" ]; then
      wait_for_pod_ready "$pod" "$timeout"
      return 0
    fi
    sleep 2
  done
  die "pod $pod was not recreated within ${timeout}s"
}

sentinel_failover() {
  local pod="$1"
  kubectl_e2e exec "$pod" -c sentinel -- \
    redis-cli -p "$E2E_SENTINEL_PORT" --raw SENTINEL failover "$E2E_MASTER_GROUP"
}

sentinel_master_addr() {
  local pod
  pod="$(redis_pods | head -n1)"
  [ -n "$pod" ] || die "no Redis pod found"
  kubectl_e2e exec "$pod" -c sentinel -- \
    redis-cli -p "$E2E_SENTINEL_PORT" --raw SENTINEL get-master-addr-by-name "$E2E_MASTER_GROUP" \
    | tr '\n' ' '
}

reset_workload_keys() {
  log "resetting workload keys"
  run_redis_cli DEL "$E2E_COUNTER_KEY" "$E2E_STOP_KEY" >/dev/null
}

start_workload() {
  log "starting workload pod $E2E_WORKLOAD_POD"
  kubectl_e2e delete pod "$E2E_WORKLOAD_POD" --ignore-not-found=true --wait=true >/dev/null
  kubectl_e2e create configmap "$E2E_WORKLOAD_CONFIGMAP" \
    --from-file=writer.sh="$ROOT_DIR/e2e/workload/writer.sh" \
    --dry-run=client -o yaml | kubectl apply -n "$E2E_NAMESPACE" -f -

  cat <<YAML | kubectl apply -n "$E2E_NAMESPACE" -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${E2E_WORKLOAD_POD}
  labels:
    release: ${E2E_RELEASE}
    app: ${E2E_APP_NAME}-e2e
spec:
  restartPolicy: Never
  containers:
    - name: writer
      image: ${E2E_WORKLOAD_IMAGE:-public.ecr.aws/docker/library/redis:8.6.3-alpine}
      imagePullPolicy: IfNotPresent
      command: ["sh", "/e2e/writer.sh"]
      env:
        - name: REDIS_HOST
          value: "$(haproxy_service)"
        - name: REDIS_PORT
          value: "${E2E_REDIS_PORT}"
        - name: E2E_KEY
          value: "${E2E_COUNTER_KEY}"
        - name: E2E_STOP_KEY
          value: "${E2E_STOP_KEY}"
        - name: E2E_INTERVAL_SECONDS
          value: "${E2E_WORKLOAD_INTERVAL_SECONDS:-0.1}"
        - name: E2E_RETRY_INTERVAL_SECONDS
          value: "${E2E_WORKLOAD_RETRY_INTERVAL_SECONDS:-0.2}"
        - name: E2E_OPERATION_TIMEOUT_SECONDS
          value: "${E2E_OPERATION_TIMEOUT_SECONDS:-15}"
        - name: E2E_MAX_SECONDS
          value: "${E2E_WORKLOAD_MAX_SECONDS:-900}"
      volumeMounts:
        - name: e2e-writer
          mountPath: /e2e
          readOnly: true
  volumes:
    - name: e2e-writer
      configMap:
        name: ${E2E_WORKLOAD_CONFIGMAP}
        defaultMode: 0755
YAML
  wait_for_pod_ready "$E2E_WORKLOAD_POD" 120
}

stop_workload() {
  log "stopping workload pod $E2E_WORKLOAD_POD"
  for _ in $(seq 1 30); do
    if run_redis_cli SET "$E2E_STOP_KEY" 1 >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  local end phase
  end=$((SECONDS + 120))
  while [ "$SECONDS" -lt "$end" ]; do
    phase="$(kubectl_e2e get pod "$E2E_WORKLOAD_POD" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    case "$phase" in
      Succeeded|Failed) break ;;
    esac
    sleep 2
  done

  mkdir -p "$E2E_ARTIFACT_DIR"
  kubectl_e2e logs "$E2E_WORKLOAD_POD" > "$E2E_ARTIFACT_DIR/${E2E_WORKLOAD_LOG_NAME:-workload.log}" 2>&1 || true
}

assert_workload() {
  local log_file="$E2E_ARTIFACT_DIR/${E2E_WORKLOAD_LOG_NAME:-workload.log}"
  [ -s "$log_file" ] || die "missing workload log: $log_file"

  local summary failed_ops max_ack final_value allowed_failed_ops
  allowed_failed_ops="${E2E_ALLOWED_FAILED_OPS:-0}"
  summary="$(grep '^summary ' "$log_file" | tail -n1 || true)"
  [ -n "$summary" ] || die "workload did not print a summary"

  failed_ops="$(printf '%s\n' "$summary" | sed -n 's/.*failed_ops=\([0-9][0-9]*\).*/\1/p')"
  max_ack="$(printf '%s\n' "$summary" | sed -n 's/.*max_ack=\([0-9][0-9]*\).*/\1/p')"
  [ -n "$failed_ops" ] || die "could not parse failed_ops from workload summary: $summary"
  [ -n "$max_ack" ] || die "could not parse max_ack from workload summary: $summary"

  if [ "$failed_ops" -gt "$allowed_failed_ops" ]; then
    die "workload exceeded failed operation budget allowed=$allowed_failed_ops: $summary"
  fi

  final_value="$(run_redis_cli GET "$E2E_COUNTER_KEY" | tr -d '\r')"
  [ -n "$final_value" ] || final_value=0
  if [ "$final_value" -lt "$max_ack" ]; then
    die "lost acknowledged writes: final_value=$final_value max_ack=$max_ack"
  fi

  log "workload verified: allowed_failed_ops=$allowed_failed_ops $summary final_value=$final_value"
}
