{{/* vim: set filetype=mustache: */}}

{{- define "config-redis.conf" }}
{{- if .Values.redis.customConfig }}
{{ tpl .Values.redis.customConfig . | indent 4 }}
{{- else }}
    dir "/data"
    port {{ .Values.redis.port }}
    {{- if .Values.sentinel.tlsPort }}
    tls-port {{ .Values.redis.tlsPort }}
    tls-cert-file /tls-certs/{{ .Values.tls.certFile }}
    tls-key-file /tls-certs/{{ .Values.tls.keyFile }}
    {{- if .Values.tls.dhParamsFile }}
    tls-dh-params-file /tls-certs/{{ .Values.tls.dhParamsFile }}
    {{- end }}
    {{- if .Values.tls.caCertFile }}
    tls-ca-cert-file /tls-certs/{{ .Values.tls.caCertFile }}
    {{- end }}
    {{- if eq (default "yes" .Values.redis.authClients) "no"}}
    tls-auth-clients no
    {{- end }}
    tls-replication {{ if .Values.redis.tlsReplication }}yes{{ else }}no{{ end }}
    {{- end }}
    {{- if .Values.redis.disableCommands }}
    {{- range .Values.redis.disableCommands }}
    rename-command {{ . }} ""
    {{- end }}
    {{- end }}
    {{- range $key, $value := .Values.redis.config }}
    {{- if kindIs "slice" $value }}
        {{- range $value }}
    {{ $key }} {{ . }}
        {{- end }}
        {{- else }}
    {{ $key }} {{ $value }}
        {{- end }}
    {{- end }}
{{- if .Values.auth }}
    requirepass replace-default-auth
    masterauth replace-default-auth
{{- end }}
{{- end }}
{{- end }}

{{- define "config-sentinel.conf" }}
{{- if .Values.sentinel.customConfig }}
{{ tpl .Values.sentinel.customConfig . | indent 4 }}
{{- else }}
    dir "/data"
    port {{ .Values.sentinel.port }}
    {{- if .Values.sentinel.bind }}
    bind {{ .Values.sentinel.bind }}
    {{- end }}
    {{- if .Values.sentinel.tlsPort }}
    tls-port {{ .Values.sentinel.tlsPort }}
    tls-cert-file /tls-certs/{{ .Values.tls.certFile }}
    tls-key-file /tls-certs/{{ .Values.tls.keyFile }}
    {{- if .Values.tls.dhParamsFile }}
    tls-dh-params-file /tls-certs/{{ .Values.tls.dhParamsFile }}
    {{- end }}
    {{- if .Values.tls.caCertFile }}
    tls-ca-cert-file /tls-certs/{{ .Values.tls.caCertFile }}
    {{- end }}
    {{- if eq (default "yes" .Values.sentinel.authClients) "no"}}
    tls-auth-clients no
    {{- end }}
    tls-replication {{ if .Values.sentinel.tlsReplication }}yes{{ else }}no{{ end }}
    {{- end }}
    {{- range $key, $value := .Values.sentinel.config }}
    {{- if eq "maxclients" $key  }}
    {{ $key }} {{ $value }}
    {{- else }}
    sentinel {{ $key }} {{ template "redis-ha.masterGroupName" $ }} {{ $value }}
    {{- end }}
    {{- end }}
{{- if .Values.auth }}
    sentinel auth-pass {{ template "redis-ha.masterGroupName" . }} replace-default-auth
{{- end }}
{{- if .Values.sentinel.auth }}
    requirepass replace-default-sentinel-auth
{{- end }}
{{- if .Values.sentinel.resolveHostnames }}
    sentinel resolve-hostnames yes
{{- end }}
{{- if .Values.sentinel.announceHostnames }}
    sentinel announce-hostnames yes
{{- end }}
{{- end }}
{{- end }}

{{- define "lib.sh" }}
    sentinel_cli() {
        _host="${1}"
        shift
        if [ "$SENTINEL_PORT" -eq 0 ]; then
            redis-cli -h "${_host}" -p "${SENTINEL_TLS_PORT}" {{ if .Values.sentinel.auth }} -a "${SENTINELAUTH}" --no-auth-warning{{ end }} --tls --cacert /tls-certs/{{ .Values.tls.caCertFile }} {{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{ end }} "$@"
        else
            redis-cli -h "${_host}" -p "${SENTINEL_PORT}" {{ if .Values.sentinel.auth }} -a "${SENTINELAUTH}" --no-auth-warning{{ end }} "$@"
        fi
    }

    # The headless service lists only ready pods, and a replica that lost its
    # master is not ready. Ask every sentinel through its announce service,
    # which also publishes not-ready pods, and take the most common answer.
    sentinel_get_master() {
    set +e
        if [ "$RESOLVE_HOSTNAMES" = true ]; then
            _addr_regex='^\s*[a-zA-Z0-9.-]+\s*$'
        else
            _addr_regex='((^\s*((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))\s*$)|(^\s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?s*$))'
        fi
        _answers=''
        _i=0
        while [ "${_i}" -lt "${REPLICA_COUNT}" ]; do
            _answer=$(sentinel_cli "${SERVICE}-announce-${_i}" sentinel get-master-addr-by-name "${MASTER_GROUP}" 2>/dev/null | head -n 1 | grep -E "${_addr_regex}")
            _answers="${_answers} ${_answer}"
            _i=$((_i + 1))
        done
        echo "${_answers}" | awk '{ for (i = 1; i <= NF; i++) votes[$i]++ } END { for (a in votes) if (votes[a] > best) { best = votes[a]; master = a } print master }'
    set -e
    }

    # Ask the sentinels in turn to fail over, until one accepts or refuses
    # for lack of a good replica. Prints that sentinel's reply.
    sentinel_failover() {
    set +e
        _reply=''
        _i=0
        while [ "${_i}" -lt "${REPLICA_COUNT}" ]; do
            _reply=$(sentinel_cli "${SERVICE}-announce-${_i}" sentinel failover "${MASTER_GROUP}" 2>&1)
            case "${_reply}" in
                OK|*NOGOODSLAVE*) break ;;
            esac
            _i=$((_i + 1))
        done
        echo "${_reply}"
    set -e
    }

    sentinel_get_master_retry() {
        master=''
        retry=${1}
        sleep=3
        for i in $(seq 1 "${retry}"); do
            master=$(sentinel_get_master)
            if [ -n "${master}" ]; then
                break
            fi
            sleep $((sleep + i))
        done
        echo "${master}"
    }

    identify_master() {
        echo "Identifying redis master (get-master-addr-by-name).."
        echo "  using sentinels ({{ template "redis-ha.fullname" . }}-announce-*), sentinel group name ({{ template "redis-ha.masterGroupName" . }})"
        MASTER="$(sentinel_get_master_retry 3)"
        if [ -n "${MASTER}" ]; then
            echo "  $(date) Found redis master (${MASTER})"
        else
            echo "  $(date) Did not find redis master (${MASTER})"
        fi
    }

    sentinel_update() {
        echo "Updating sentinel config.."
        echo "  evaluating sentinel id (\${SENTINEL_ID_${INDEX}})"
        eval MY_SENTINEL_ID="\$SENTINEL_ID_${INDEX}"
        echo "  sentinel id (${MY_SENTINEL_ID}), sentinel grp (${MASTER_GROUP}), quorum (${QUORUM})"
        sed -i "1s/^/sentinel myid ${MY_SENTINEL_ID}\\n/" "${SENTINEL_CONF}"
        if [ "$SENTINEL_TLS_REPLICATION_ENABLED" = true ]; then
            echo "  redis master (${1}:${REDIS_TLS_PORT})"
            sed -i "2s/^/sentinel monitor ${MASTER_GROUP} ${1} ${REDIS_TLS_PORT} ${QUORUM} \\n/" "${SENTINEL_CONF}"
        else
            echo "  redis master (${1}:${REDIS_PORT})"
            sed -i "2s/^/sentinel monitor ${MASTER_GROUP} ${1} ${REDIS_PORT} ${QUORUM} \\n/" "${SENTINEL_CONF}"
        fi
        echo "sentinel announce-ip ${ANNOUNCE_IP}" >> ${SENTINEL_CONF}
        if [ "$SENTINEL_PORT" -eq 0 ]; then
            echo "  announce (${ANNOUNCE_IP}:${SENTINEL_TLS_PORT})"
            echo "sentinel announce-port ${SENTINEL_TLS_PORT}" >> ${SENTINEL_CONF}
        else
            echo "  announce (${ANNOUNCE_IP}:${SENTINEL_PORT})"
            echo "sentinel announce-port ${SENTINEL_PORT}" >> ${SENTINEL_CONF}
        fi
    }

    redis_update() {
        echo "Updating redis config.."
        if [ "$REDIS_TLS_REPLICATION_ENABLED" = true ]; then
            echo "  we are slave of redis master (${1}:${REDIS_TLS_PORT})"
            echo "slaveof ${1} ${REDIS_TLS_PORT}" >> "${REDIS_CONF}"
            echo "slave-announce-port ${REDIS_TLS_PORT}" >> ${REDIS_CONF}
        else
            echo "  we are slave of redis master (${1}:${REDIS_PORT})"
            echo "slaveof ${1} ${REDIS_PORT}" >> "${REDIS_CONF}"
            echo "slave-announce-port ${REDIS_PORT}" >> ${REDIS_CONF}
        fi
        echo "slave-announce-ip ${ANNOUNCE_IP}" >> ${REDIS_CONF}
    }

    copy_config() {
        echo "Copying default redis config.."
        echo "  to '${REDIS_CONF}'"
        cp /readonly-config/redis.conf "${REDIS_CONF}"
        echo "Copying default sentinel config.."
        echo "  to '${SENTINEL_CONF}'"
        cp /readonly-config/sentinel.conf "${SENTINEL_CONF}"
    }

    redis_cli_at() {
        _host="${1}"
        shift
        if [ "$REDIS_PORT" -eq 0 ]; then
            redis-cli -h "${_host}"{{ if .Values.auth }} -a "${AUTH}" --no-auth-warning{{ end }} -p "${REDIS_TLS_PORT}" --tls --cacert /tls-certs/{{ .Values.tls.caCertFile }} {{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{ end }} "$@"
        else
            redis-cli -h "${_host}"{{ if .Values.auth }} -a "${AUTH}" --no-auth-warning{{ end }} -p "${REDIS_PORT}" "$@"
        fi
    }

    # Prints the role ("master" or "slave") the redis at $1 reports, or
    # nothing when it does not answer.
    redis_role_at() {
    set +e
        redis_cli_at "${1}" role 2>/dev/null | head -n 1
    set -e
    }

    # Sets DEFAULT_MASTER to another member that really holds the master
    # role: the one sentinel names if it does, otherwise the first member
    # found. Sets REACHABLE_MEMBERS to the number of other members that
    # answered.
    find_role_master() {
        DEFAULT_MASTER=''
        REACHABLE_MEMBERS=0
        _named="$(sentinel_get_master)"
        if [ -n "${_named}" ] && [ "${_named}" != "${ANNOUNCE_IP}" ] && [ "$(redis_role_at "${_named}")" = "master" ]; then
            DEFAULT_MASTER="${_named}"
        fi
        _i=0
        while [ "${_i}" -lt "${REPLICA_COUNT}" ]; do
            if [ "${_i}" != "${INDEX}" ]; then
                _role="$(redis_role_at "${SERVICE}-announce-${_i}")"
                if [ -n "${_role}" ]; then
                    REACHABLE_MEMBERS=$((REACHABLE_MEMBERS + 1))
                fi
                if [ "${_role}" = "master" ] && [ -z "${DEFAULT_MASTER}" ]; then
                    DEFAULT_MASTER="$(getent_hosts "${_i}" | awk '{ print $1 }')"
                fi
            fi
            _i=$((_i + 1))
        done
    }

    # Never follow a member that is not master: a replica of a replica
    # forms a loop that sentinel cannot break. Wait for a master instead.
    # Pod 0 makes itself master when no other member answers, as on a
    # fresh install, or after MASTERLESS_WAIT_ROUNDS rounds of waiting.
    setup_defaults() {
        echo "Setting up defaults.."
        echo "  using statefulset index (${INDEX})"
        _round=0
        while true; do
            find_role_master
            if [ -n "${DEFAULT_MASTER}" ]; then
                echo "  $(date) Found member holding the master role (${DEFAULT_MASTER})"
                echo "Setting default slave config for redis and sentinel.."
                redis_update "${DEFAULT_MASTER}"
                sentinel_update "${DEFAULT_MASTER}"
                return 0
            fi
            if [ "${INDEX}" = "0" ] && { [ "${REACHABLE_MEMBERS}" -eq 0 ] || [ "${_round}" -ge "${MASTERLESS_WAIT_ROUNDS}" ]; }; then
                echo "Setting this pod as master for redis and sentinel.."
                echo "  using announce (${ANNOUNCE_IP})"
                redis_update "${ANNOUNCE_IP}"
                sentinel_update "${ANNOUNCE_IP}"
                echo "  make sure ${ANNOUNCE_IP} is not a slave (slaveof no one)"
                sed -i "s/^.*slaveof.*//" "${REDIS_CONF}"
                return 0
            fi
            _round=$((_round + 1))
            echo "  $(date) No member holds the master role (${REACHABLE_MEMBERS} other members answered). Waiting, round ${_round}.."
            sleep 10
        done
    }

    redis_ping() {
    set +e
        if [ "$REDIS_PORT" -eq 0 ]; then
            redis-cli -h "${MASTER}"{{ if .Values.auth }} -a "${AUTH}" --no-auth-warning{{ end }} -p "${REDIS_TLS_PORT}" --tls --cacert /tls-certs/{{ .Values.tls.caCertFile }} {{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{ end }} ping
        else
            redis-cli -h "${MASTER}"{{ if .Values.auth }} -a "${AUTH}" --no-auth-warning{{ end }} -p "${REDIS_PORT}" ping
        fi
    set -e
    }

    redis_ping_retry() {
        ping=''
        retry=${1}
        sleep=3
        for i in $(seq 1 "${retry}"); do
            # Our own announce address is not a master we can follow: this
            # pod is starting, and the address may still reach its predecessor.
            if [ "${MASTER}" != "${ANNOUNCE_IP}" ] && [ "$(redis_ping)" = "PONG" ] && [ "$(redis_role_at "${MASTER}")" = "master" ]; then
               ping='PONG'
               break
            fi
            sleep $((sleep + i))
            MASTER=$(sentinel_get_master)
        done
        echo "${ping}"
    }

    find_master() {
        echo "Verifying redis master.."
        if [ "$REDIS_PORT" -eq 0 ]; then
            echo "  ping (${MASTER}:${REDIS_TLS_PORT})"
        else
            echo "  ping (${MASTER}:${REDIS_PORT})"
        fi
        if [ "$(redis_ping_retry 3)" != "PONG" ]; then
            echo "  $(date) Can't ping redis master (${MASTER})"
            # Sentinel may have failed over meanwhile. Forcing another
            # failover would move a healthy new master again.
            find_role_master
            if [ -n "${DEFAULT_MASTER}" ]; then
                echo "  $(date) Found member holding the master role (${DEFAULT_MASTER})"
                echo "Updating redis and sentinel config.."
                sentinel_update "${DEFAULT_MASTER}"
                redis_update "${DEFAULT_MASTER}"
                return 0
            fi
            echo "Attempting to force failover (sentinel failover).."
            echo "  on sentinels (${SERVICE}-announce-*), sentinel grp (${MASTER_GROUP})"
            if sentinel_failover | grep -q 'NOGOODSLAVE' ; then
                echo "  $(date) Failover returned with 'NOGOODSLAVE'"
                echo "Setting defaults for this pod.."
                setup_defaults
                return 0
            fi

            echo "Hold on for 10sec"
            sleep 10
            echo "We should get redis master's ip now. Asking (get-master-addr-by-name).."
            echo "  sentinels (${SERVICE}-announce-*), sentinel grp (${MASTER_GROUP})"
            MASTER="$(sentinel_get_master)"
            if [ "${MASTER}" ] && [ "${MASTER}" != "${ANNOUNCE_IP}" ]; then
                echo "  $(date) Found redis master (${MASTER})"
                echo "Updating redis and sentinel config.."
                sentinel_update "${MASTER}"
                redis_update "${MASTER}"
            else
                echo "  $(date) Sentinel still names no other master"
                setup_defaults
            fi
        else
            echo "  $(date) Found reachable redis master (${MASTER})"
            echo "Updating redis and sentinel config.."
            sentinel_update "${MASTER}"
            redis_update "${MASTER}"
        fi
    }

    redis_ro_update() {
        echo "Updating read-only redis config.."
        echo "  redis.conf set 'replica-priority 0'"
        echo "replica-priority 0" >> ${REDIS_CONF}
    }

    getent_hosts() {
        index=${1:-${INDEX}}
        service="${SERVICE}-announce-${index}"
        if [ "$RESOLVE_HOSTNAMES" = true ]; then
            echo "${service}.${NAMESPACE}.svc"
        else
            host=$(getent hosts "${service}")
            echo "${host}"
        fi
    }

    identify_announce_ip() {
        if [ "$ANNOUNCE_HOSTNAMES" = true ]; then
            echo "Identify announce hostname for this pod.."
            echo "  using (${SERVICE}-announce-${INDEX}.${NAMESPACE}.svc)"
            ANNOUNCE_IP="${SERVICE}-announce-${INDEX}.${NAMESPACE}.svc"
        else
            echo "Identify announce ip for this pod.."
            echo "  using (${SERVICE}-announce-${INDEX}) or (${SERVICE}-server-${INDEX})"
            ANNOUNCE_IP=$(getent_hosts | awk '{ print $1 }')
        fi
        echo "  identified announce (${ANNOUNCE_IP})"
    }
{{- end }}

{{- define "vars.sh" }}
    HOSTNAME="$(cat /proc/sys/kernel/hostname)"
    {{- if .Values.ro_replicas }}
    RO_REPLICAS="{{ .Values.ro_replicas }}"
    {{- end }}
    INDEX="${HOSTNAME##*-}"
    SENTINEL_PORT={{ .Values.sentinel.port }}
    ANNOUNCE_IP=''
    MASTER=''
    MASTER_GROUP="{{ template "redis-ha.masterGroupName" . }}"
    QUORUM="{{ .Values.sentinel.quorum }}"
    REDIS_CONF=/data/conf/redis.conf
    REDIS_PORT={{ .Values.redis.port }}
    REDIS_TLS_PORT={{ .Values.redis.tlsPort }}
    SENTINEL_CONF=/data/conf/sentinel.conf
    SENTINEL_TLS_PORT={{ .Values.sentinel.tlsPort }}
    SERVICE={{ template "redis-ha.fullname" . }}
    REPLICA_COUNT={{ .Values.replicas }}
    MASTERLESS_WAIT_ROUNDS=${MASTERLESS_WAIT_ROUNDS:-12}
    NAMESPACE="{{ .Release.Namespace }}"
    SENTINEL_TLS_REPLICATION_ENABLED={{ default false .Values.sentinel.tlsReplication }}
    REDIS_TLS_REPLICATION_ENABLED={{ default false .Values.redis.tlsReplication }}
    RESOLVE_HOSTNAMES={{ default false .Values.sentinel.resolveHostnames }}
    ANNOUNCE_HOSTNAMES={{ default false .Values.sentinel.announceHostnames }}
{{- end }}

{{- define "config-init.sh" }}
    echo "$(date) Start..."
    {{- include "vars.sh" . }}

    set -eu

    {{- include "lib.sh" . }}

    mkdir -p /data/conf/
    # A pod start, not a container restart: see redis-start.sh.
    rm -f /data/conf/.redis-started

    echo "Initializing config.."
    copy_config

    # where is redis master
    identify_master

    identify_announce_ip

    if [ -z "${ANNOUNCE_IP}" ]; then
        echo "Error: Could not resolve the announce address for this pod"
        exit 1
    elif [ "${MASTER}" ]; then
        find_master
    else
        setup_defaults
    fi

    {{- if .Values.ro_replicas }}
    # works only if index is less than 10
    echo "Verifying redis read-only replica.."
    echo "  we have RO_REPLICAS='${RO_REPLICAS}' with INDEX='${INDEX}'"
    if echo "${RO_REPLICAS}" | grep -q "${INDEX}" ; then
        redis_ro_update
    fi
    {{- end }}

    if [ "${AUTH:-}" ]; then
        echo "Setting redis auth values.."
        ESCAPED_AUTH=$(echo "${AUTH}" | sed -e 's/[\/&]/\\&/g');
        sed -i "s/replace-default-auth/${ESCAPED_AUTH}/" "${REDIS_CONF}" "${SENTINEL_CONF}"
    fi

    if [ "${SENTINELAUTH:-}" ]; then
        echo "Setting sentinel auth values"
        ESCAPED_AUTH_SENTINEL=$(echo "$SENTINELAUTH" | sed -e 's/[\/&]/\\&/g');
        sed -i "s/replace-default-sentinel-auth/${ESCAPED_AUTH_SENTINEL}/" "$SENTINEL_CONF"
    fi

    echo "$(date) Ready..."
{{- end }}

{{- define "redis-start.sh" }}
    {{- include "vars.sh" . }}

    set -eu

    {{- include "lib.sh" . }}

    # config-init removes the marker on every pod start, so finding it means
    # the redis container restarted inside a running pod: a crash, an OOM
    # kill or a failed liveness probe. If sentinel still names this node as
    # master, its data is older than its replicas' data. Starting it as
    # master would make every replica resync from that older data. Ask
    # sentinel to promote a replica first, and start as its replica.
    if [ -f /data/conf/.redis-started ]; then
        identify_announce_ip
        MASTER="$(sentinel_get_master)"
        if [ -n "${ANNOUNCE_IP}" ] && [ "${MASTER}" = "${ANNOUNCE_IP}" ]; then
            echo "$(date) Restarted while sentinel names this node as master; failing over first.."
            echo "  sentinel replied: $(sentinel_failover)"
            _wait=0
            while [ "${_wait}" -lt 30 ] && [ "$(sentinel_get_master)" = "${ANNOUNCE_IP}" ]; do
                sleep 1
                _wait=$((_wait + 1))
            done
            MASTER="$(sentinel_get_master)"
            if [ -n "${MASTER}" ] && [ "${MASTER}" != "${ANNOUNCE_IP}" ]; then
                sed -i -e '/^slaveof /d' -e '/^replicaof /d' "${REDIS_CONF}"
                redis_update "${MASTER}"
            else
                echo "  $(date) No other master; starting with the local data."
            fi
        fi
    fi
    touch /data/conf/.redis-started
    exec redis-server "$@"
{{- end }}

{{- define "trigger-failover-if-master.sh" }}
    {{- if or (eq (int .Values.redis.port) 0) (eq (int .Values.sentinel.port) 0) }}
    TLS_CLIENT_OPTION="--tls --cacert /tls-certs/{{ .Values.tls.caCertFile }}{{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{end}}"
    {{- end }}
    {{- $masterGroupName := include "redis-ha.masterGroupName" . }}
    redis_local() {
      redis-cli \
      {{- if .Values.auth }}
        -a "${AUTH}" --no-auth-warning \
      {{- end }}
        -h localhost \
      {{- if (int .Values.redis.port) }}
        -p {{ .Values.redis.port }} \
      {{- else }}
        -p {{ .Values.redis.tlsPort }} ${TLS_CLIENT_OPTION} \
      {{- end}}
        "$@"
    }
    sentinel_local() {
      redis-cli \
      {{- if .Values.sentinel.auth }}
        -a "${SENTINELAUTH}" --no-auth-warning \
      {{- end }}
        -h localhost \
      {{- if (int .Values.sentinel.port) }}
        -p {{ .Values.sentinel.port }} \
      {{- else }}
        -p {{ .Values.sentinel.tlsPort }} ${TLS_CLIENT_OPTION} \
      {{- end}}
        "$@"
    }
    get_redis_role() {
      is_master=$(redis_local info replication | grep -c 'role:master' || true)
    }
    get_redis_role
    if [ "$is_master" -eq 1 ]; then
      echo "This node is currently master, we trigger a failover."
      # Hold writes during the handoff. A write this node accepts after the
      # promotion is lost. A held write fails with READONLY once this node is
      # a replica, and the client retries it on the new master.
      if [ "$(redis_local client pause 35000 write)" != "OK" ]; then
        echo "Could not pause writes, failing over without the pause."
      fi
      old_master=$(sentinel_local sentinel get-master-addr-by-name {{ $masterGroupName }} | head -n 1)
      response=$(sentinel_local sentinel failover {{ $masterGroupName }})
      if [ "$response" != "OK" ] ; then
        echo "$response"
        redis_local client unpause >/dev/null
        exit 1
      fi
      timeout=30
      while [ "$is_master" -eq 1 ] && [ "$timeout" -gt 0 ]; do
        sleep 1
        # Follow the promoted node at once. Sentinel demotes this node only on
        # its next check, which keeps the held writes waiting longer.
        new_master=$(sentinel_local sentinel get-master-addr-by-name {{ $masterGroupName }} | tr '\n' ' ')
        # shellcheck disable=SC2086
        set -- $new_master
        if [ -n "${1:-}" ] && [ "$1" != "$old_master" ]; then
          redis_local replicaof "$1" "$2" >/dev/null
        fi
        get_redis_role
        timeout=$((timeout - 1))
        # Sentinel can accept the request and then abort it, for example
        # when no replica qualifies. Stop holding writes when that happens.
        if [ "$is_master" -eq 1 ] && [ "$timeout" -lt 27 ] && \
           ! sentinel_local sentinel master {{ $masterGroupName }} | grep -q failover_in_progress; then
          echo "Sentinel is no longer failing over."
          break
        fi
      done
      redis_local client unpause >/dev/null
      if [ "$is_master" -eq 1 ]; then
        echo "Failover did not complete within 30s."
        exit 1
      fi
      echo "Failover successful"
    fi
{{- end }}

{{- define "fix-split-brain.sh" }}
    {{- include "vars.sh" . }}

    ROLE=''
    REDIS_MASTER=''

    set -eu

    {{- include "lib.sh" . }}

    redis_role() {
    set +e
        if [ "$REDIS_PORT" -eq 0 ]; then
            ROLE=$(redis-cli {{ if .Values.auth }} -a "${AUTH}" --no-auth-warning{{ end }} -p "${REDIS_TLS_PORT}" --tls --cacert /tls-certs/{{ .Values.tls.caCertFile }} {{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{ end }} info | grep role | sed 's/role://' | sed 's/\r//')
        else
            ROLE=$(redis-cli {{ if .Values.auth }} -a "${AUTH}" --no-auth-warning{{ end }} -p "${REDIS_PORT}" info | grep role | sed 's/role://' | sed 's/\r//')
        fi
    set -e
    }

    identify_redis_master() {
    set +e
        if [ "$REDIS_PORT" -eq 0 ]; then
            REDIS_MASTER=$(redis-cli {{ if .Values.auth }} -a "${AUTH}" --no-auth-warning{{ end }} -p "${REDIS_TLS_PORT}" --tls --cacert /tls-certs/{{ .Values.tls.caCertFile }} {{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{ end }} info | grep master_host | sed 's/master_host://' | sed 's/\r//')
        else
            REDIS_MASTER=$(redis-cli {{ if .Values.auth }} -a "${AUTH}" --no-auth-warning{{ end }} -p "${REDIS_PORT}" info | grep master_host | sed 's/master_host://' | sed 's/\r//')
        fi
    set -e
    }

    reinit() {
    set +e
        sh /readonly-config/init.sh

        if [ "$REDIS_PORT" -eq 0 ]; then
            echo "shutdown" | redis-cli {{ if .Values.auth }} -a "${AUTH}" --no-auth-warning{{ end }} -p "${REDIS_TLS_PORT}" --tls --cacert /tls-certs/{{ .Values.tls.caCertFile }} {{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{ end }}
        else
            echo "shutdown" | redis-cli {{ if .Values.auth }} -a "${AUTH}" --no-auth-warning{{ end }} -p "${REDIS_PORT}"
        fi
    set -e
    }

    master_actual_role() {
    set +e
        if [ "$REDIS_PORT" -eq 0 ]; then
            MASTER_ACTUAL_ROLE=$(redis-cli {{ if .Values.auth }} -a "${AUTH}" --no-auth-warning{{ end }} -h "${MASTER}" -p "${REDIS_TLS_PORT}" --tls --cacert /tls-certs/{{ .Values.tls.caCertFile }} {{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{ end }} info | grep role | sed 's/role://' | sed 's/\r//')
        else
            MASTER_ACTUAL_ROLE=$(redis-cli {{ if .Values.auth }} -a "${AUTH}" --no-auth-warning{{ end }} -h "${MASTER}" -p "${REDIS_PORT}" info | grep role | sed 's/role://' | sed 's/\r//')
        fi
    set -e
    }

    REDIS_ACTIVE_PORT="${REDIS_PORT}"
    [ "$REDIS_PORT" -eq 0 ] && REDIS_ACTIVE_PORT="${REDIS_TLS_PORT}"

    announce_info() {
    set +e
        redis_cli_at "$1" info replication 2>/dev/null | sed 's/\r//'
    set -e
    }

    announce_cmd() {
    set +e
        redis_cli_at "$@"
    set -e
    }

    announce_sentinel_cmd() {
    set +e
        sentinel_cli "$@"
    set -e
    }

    # True when at least a quorum of sentinels flag the named master as down,
    # so a master this pod cannot reach is not just cut off from this pod.
    sentinels_see_master_down() {
        _down=0
        _k=0
        while [ "$_k" -lt "$REPLICA_COUNT" ]; do
            if announce_sentinel_cmd "${SERVICE}-announce-${_k}" sentinel master "${MASTER_GROUP}" 2>/dev/null | grep -q 's_down'; then
                _down=$((_down + 1))
            fi
            _k=$((_k + 1))
        done
        [ "$_down" -ge "$QUORUM" ]
    }

    # True if no member holds the master role.
    masterless_now() {
        _j=0
        while [ "$_j" -lt "$REPLICA_COUNT" ]; do
            _r=$(announce_info "${SERVICE}-announce-${_j}" | awk -F: '/^role:/{print $2}')
            [ "$_r" = "master" ] && return 1
            _j=$((_j + 1))
        done
        return 0
    }

    # A masterless set never recovers on its own, so confirm it over seconds
    # rather than over detection cycles. Any master seen aborts.
    confirm_masterless_and_heal() {
        _c=0
        while [ "$_c" -lt "$MASTERLESS_CONFIRMATIONS" ]; do
            if ! masterless_now; then
                echo "A member holds the master role; standing down after $_c/$MASTERLESS_CONFIRMATIONS confirmations."
                return 1
            fi
            _c=$((_c + 1))
            [ "$_c" -lt "$MASTERLESS_CONFIRMATIONS" ] && sleep "$MASTERLESS_CONFIRM_INTERVAL"
        done
        echo "No member held the master role across $MASTERLESS_CONFIRMATIONS consecutive checks."
        promote_best_member
    }

    # Promote the highest-offset member. Sentinel cannot: once every candidate
    # looks stale it aborts with -failover-abort-no-good-slave / -NOGOODSLAVE.
    promote_best_member() {
        # Rescan: a liveness-killed redis is briefly unreachable.
        _try=0
        while [ "$_try" -lt "$PROMOTE_SCAN_ATTEMPTS" ]; do
            _best=''
            _best_off=-1
            _i=0
            while [ "$_i" -lt "$REPLICA_COUNT" ]; do
                _info=$(announce_info "${SERVICE}-announce-${_i}")
                _role=$(echo "$_info" | awk -F: '/^role:/{print $2}')
                if [ "$_role" = "master" ]; then
                    echo "A master is present at ${SERVICE}-announce-${_i}; no promotion needed."
                    return 1
                fi
                _off=$(echo "$_info" | awk -F: '/_repl_offset:/{print $2; exit}')
                case "$_off" in
                    ''|*[!0-9]*) ;;
                    *) if [ "$_off" -gt "$_best_off" ]; then _best_off="$_off"; _best="$_i"; fi ;;
                esac
                _i=$((_i + 1))
            done
            [ -n "$_best" ] && break
            _try=$((_try + 1))
            echo "Masterless, but no member answered (attempt $_try/$PROMOTE_SCAN_ATTEMPTS) — members may be restarting."
            [ "$_try" -lt "$PROMOTE_SCAN_ATTEMPTS" ] && sleep "$MASTERLESS_CONFIRM_INTERVAL"
        done
        if [ -z "$_best" ]; then
            echo "Masterless, but no member is reachable — not promoting."
            return 1
        fi
        _best_host="${SERVICE}-announce-${_best}"
        _best_ip=$(getent_hosts "$_best" | awk '{ print $1 }')
        echo "ERROR: no member holds the master role. Promoting ${_best_host} (replication offset ${_best_off})."
        announce_cmd "$_best_host" replicaof no one
        _i=0
        while [ "$_i" -lt "$REPLICA_COUNT" ]; do
            if [ "$_i" -ne "$_best" ] && [ -n "$_best_ip" ]; then
                announce_cmd "${SERVICE}-announce-${_i}" replicaof "$_best_ip" "$REDIS_ACTIVE_PORT"
            fi
            _i=$((_i + 1))
        done
        if [ -n "$_best_ip" ]; then
            repoint_sentinels "$_best_ip"
        else
            echo "WARNING: could not resolve ${_best_host}; leaving sentinel config untouched."
        fi
        echo "Promotion complete: ${_best_host} is now master."
        return 0
    }

    # Address and index of whichever member currently holds the master role
    # ('' if none).
    find_actual_master() {
        ACTUAL_MASTER_INDEX=''
        ACTUAL_MASTER_ADDR=''
        _m=0
        while [ "$_m" -lt "$REPLICA_COUNT" ]; do
            _r=$(announce_info "${SERVICE}-announce-${_m}" | awk -F: '/^role:/{print $2}')
            if [ "$_r" = "master" ]; then
                ACTUAL_MASTER_INDEX="$_m"
                ACTUAL_MASTER_ADDR=$(getent_hosts "$_m" | awk '{ print $1 }')
                return 0
            fi
            _m=$((_m + 1))
        done
        return 0
    }

    # Rewrite every sentinel's monitor entry to point at $1. 'sentinel reset'
    # is not enough: it rediscovers from the stale configured address, so a
    # wrong entry survives it.
    repoint_sentinels() {
        if [ "$SENTINEL_TLS_REPLICATION_ENABLED" = true ]; then
            _monitor_port="${REDIS_TLS_PORT}"
        else
            _monitor_port="${REDIS_PORT}"
        fi
        _k=0
        while [ "$_k" -lt "$REPLICA_COUNT" ]; do
            announce_sentinel_cmd "${SERVICE}-announce-${_k}" sentinel remove "${MASTER_GROUP}"
            announce_sentinel_cmd "${SERVICE}-announce-${_k}" sentinel monitor "${MASTER_GROUP}" "$1" "$_monitor_port" "$QUORUM"
            # A new monitor entry starts from sentinel's defaults. Put back what
            # sentinel.conf sets, or the sentinel cannot authenticate to the master.
            {{- if not .Values.sentinel.customConfig }}
            {{- range $key, $value := .Values.sentinel.config }}
            {{- if ne "maxclients" $key }}
            announce_sentinel_cmd "${SERVICE}-announce-${_k}" sentinel set "${MASTER_GROUP}" {{ $key }} {{ $value }}
            {{- end }}
            {{- end }}
            {{- end }}
            {{- if .Values.auth }}
            announce_sentinel_cmd "${SERVICE}-announce-${_k}" sentinel set "${MASTER_GROUP}" auth-pass "${AUTH}"
            {{- end }}
            _k=$((_k + 1))
        done
        echo "Repointed sentinels: monitor ${MASTER_GROUP} ${1}:${_monitor_port} quorum ${QUORUM}"
    }

    # Sentinel's named master does not hold the master role. Trust the data
    # plane instead of forcing a blind failover (which would demote a healthy
    # master if sentinel's answer was merely stale): if some member really is
    # master, repoint every sentinel at it; only if none is, force a failover
    # and promote directly if sentinel cannot (-NOGOODSLAVE).
    heal_stale_sentinel() {
        find_actual_master
        if [ -n "$ACTUAL_MASTER_INDEX" ]; then
            if [ "$ACTUAL_MASTER_INDEX" = "$INDEX" ]; then
                echo "This pod holds the master role after all; nothing to heal."
            elif [ -n "$ACTUAL_MASTER_ADDR" ]; then
                echo "ERROR: sentinel names ${MASTER} as master but ${SERVICE}-announce-${ACTUAL_MASTER_INDEX} (${ACTUAL_MASTER_ADDR}) holds the role. Repointing sentinels instead of failing over..."
                repoint_sentinels "$ACTUAL_MASTER_ADDR"
            else
                echo "WARNING: ${SERVICE}-announce-${ACTUAL_MASTER_INDEX} holds the master role but its address did not resolve; leaving sentinel config untouched."
            fi
            return 0
        fi
        echo "ERROR: no member holds the master role. Forcing a failover..."
        sentinel_failover || true
        # SENTINEL FAILOVER returns -NOGOODSLAVE when no candidate looks
        # fresh; promote directly instead.
        sleep {{ .Values.splitBrainDetection.retryInterval }}
        confirm_masterless_and_heal || true
    }

    identify_announce_ip

    while [ -z "${ANNOUNCE_IP}" ]; do
        echo "Error: Could not resolve the announce address for this pod."
        sleep 30
        identify_announce_ip
    done

    QUORUM_FAIL_COUNT=0
    MAX_QUORUM_FAILURES=${MAX_QUORUM_FAILURES:-5}
    STALE_MASTER_COUNT=0
    MAX_STALE_MASTER_FAILURES=${MAX_STALE_MASTER_FAILURES:-3}
    # Confirmations required before promoting, and the gap between them.
    MASTERLESS_CONFIRMATIONS=${MASTERLESS_CONFIRMATIONS:-5}
    MASTERLESS_CONFIRM_INTERVAL=${MASTERLESS_CONFIRM_INTERVAL:-5}
    PROMOTE_SCAN_ATTEMPTS=${PROMOTE_SCAN_ATTEMPTS:-6}

    trap "exit 0" TERM
    while true; do
        sleep {{ .Values.splitBrainDetection.interval }}

        # where is redis master
        identify_master

        if [ "$MASTER" = "$ANNOUNCE_IP" ]; then
            QUORUM_FAIL_COUNT=0
            redis_role
            if [ "$ROLE" != "master" ]; then
                echo "waiting for redis to become master"
                sleep {{ .Values.splitBrainDetection.retryInterval }}
                identify_master
                redis_role
                echo "Redis role is $ROLE, expected role is master. No need to reinitialize."
                if [ "$ROLE" != "master" ]; then
                    # Sentinel names this pod as master but it runs as a replica:
                    # reinit would re-derive `slaveof` and shutdown, restarting the
                    # pod straight back into a replica while sentinel keeps naming
                    # it (#383). This pod is also the fastest observer of the
                    # broken state, so heal here instead of waiting for peers'
                    # stale-master counters. Promotion stays offset-aware — a
                    # freshly replaced (empty) pod behind a stale sentinel record
                    # must not be promoted just because sentinel names it.
                    echo "Redis role is $ROLE but sentinel names this pod as master; healing from data-plane truth"
                    heal_stale_sentinel
                    if [ -n "$ACTUAL_MASTER_INDEX" ] && [ "$ACTUAL_MASTER_INDEX" != "$INDEX" ]; then
                        # Sentinels now point at the real master; reinit so
                        # init.sh reconfigures this pod as its replica.
                        reinit
                    fi
                fi
            fi
        elif [ "${MASTER}" ]; then
            QUORUM_FAIL_COUNT=0
            identify_redis_master
            if [ "$REDIS_MASTER" != "$MASTER" ]; then
                echo "Redis master and local master are not the same. waiting."
                sleep {{ .Values.splitBrainDetection.retryInterval }}
                identify_master
                if [ "$MASTER" = "$ANNOUNCE_IP" ]; then
                    echo "This pod became master during wait, skipping reinit"
                else
                    identify_redis_master
                    echo "Redis master is ${MASTER}, expected master is ${REDIS_MASTER}. No need to reinitialize."
                    if [ "${REDIS_MASTER}" != "${MASTER}" ]; then
                        echo "Redis master is ${MASTER}, expected master is ${REDIS_MASTER}, reinitializing"
                        reinit
                    fi
                fi
            else
                # Agreeing with sentinel is not enough: the named master may
                # itself be a replica, leaving the set with no master at all.
                master_actual_role
                if [ "${MASTER_ACTUAL_ROLE}" = "master" ]; then
                    STALE_MASTER_COUNT=0
                elif [ -z "${MASTER_ACTUAL_ROLE}" ] && ! sentinels_see_master_down; then
                    # Unreachable from this pod only: sentinel's own down detection decides.
                    STALE_MASTER_COUNT=0
                else
                    # A named master that stays down for several checks gets no
                    # failover when sentinel finds no good replica either.
                    STALE_MASTER_COUNT=$((STALE_MASTER_COUNT + 1))
                    echo "WARNING: Sentinel names ${MASTER} as master but its actual role is '${MASTER_ACTUAL_ROLE:-unreachable}' (set may be masterless). Failure count: $STALE_MASTER_COUNT/$MAX_STALE_MASTER_FAILURES"
                    if [ "$STALE_MASTER_COUNT" -ge "$MAX_STALE_MASTER_FAILURES" ]; then
                        echo "ERROR: Sentinel-named master has not held the master role for $MAX_STALE_MASTER_FAILURES consecutive checks. Healing..."
                        heal_stale_sentinel
                        STALE_MASTER_COUNT=0
                    fi
                fi
            fi
        else
            QUORUM_FAIL_COUNT=$((QUORUM_FAIL_COUNT + 1))
            echo "WARNING: Sentinel returned no master (quorum may be broken). Failure count: $QUORUM_FAIL_COUNT/$MAX_QUORUM_FAILURES"
            # No master named is also what a masterless set looks like; the
            # reset below still runs on its own schedule for real quorum loss.
            confirm_masterless_and_heal || true
            if [ "$QUORUM_FAIL_COUNT" -ge "$MAX_QUORUM_FAILURES" ]; then
                echo "ERROR: Quorum broken for $MAX_QUORUM_FAILURES consecutive checks. Attempting sentinel reset..."
                _i=0
                while [ "${_i}" -lt "${REPLICA_COUNT}" ]; do
                    if sentinel_cli "${SERVICE}-announce-${_i}" sentinel reset "${MASTER_GROUP}"; then
                        break
                    fi
                    _i=$((_i + 1))
                done
                QUORUM_FAIL_COUNT=0
            fi
        fi
    done

{{- end }}

{{- define "config-haproxy.cfg" }}
{{- if .Values.haproxy.customConfig }}
{{ tpl .Values.haproxy.customConfig . | indent 4 }}
{{- else }}
    defaults REDIS
      mode tcp
      timeout connect {{ .Values.haproxy.timeout.connect }}
      timeout server {{ .Values.haproxy.timeout.server }}
      timeout client {{ .Values.haproxy.timeout.client }}
      timeout check {{ .Values.haproxy.timeout.check }}
      timeout tunnel {{ .Values.haproxy.timeout.tunnel }}

    listen health_check_http_url
      bind {{ if .Values.haproxy.IPv6.enabled }}[::]{{ end }}:8888  {{ if .Values.haproxy.IPv6.enabled }}v4v6{{ end }}
      mode http
      monitor-uri /healthz
      option      dontlognull

    {{- $root := . }}
    {{- $fullName := include "redis-ha.fullname" . }}
    {{- $replicas := int (toString .Values.replicas) }}
    {{- $masterGroupName := include "redis-ha.masterGroupName" . }}
    {{- range $i := until $replicas }}
    # Check Sentinel and whether they are nominated master
    backend check_if_redis_is_master_{{ $i }}
      mode tcp
      option tcp-check
      tcp-check connect
      {{- if $root.Values.sentinel.auth }}
      tcp-check send "AUTH ${SENTINELAUTH}"\r\n
      tcp-check expect string +OK
      {{- end }}
      tcp-check send PING\r\n
      tcp-check expect string +PONG
      tcp-check send SENTINEL\ get-master-addr-by-name\ {{ $masterGroupName }}\r\n
      tcp-check expect string REPLACE_ANNOUNCE{{ $i }}
      tcp-check send QUIT\r\n
      {{- range $i := until $replicas }}
      {{- if $.Values.sentinel.resolveHostnames }}
      server R{{ $i }} {{ $fullName }}-announce-{{ $i }}.{{ $.Release.Namespace }}.svc:26379 check inter {{ $root.Values.haproxy.checkInterval }}
      {{- else }}
      server R{{ $i }} {{ $fullName }}-announce-{{ $i }}:26379 check inter {{ $root.Values.haproxy.checkInterval }}
      {{- end }}
      {{- end }}
    {{- end }}

    # decide redis backend to use
    #master
    frontend ft_redis_master
      {{- if .Values.haproxy.tls.enabled }}
      bind {{ if .Values.haproxy.IPv6.enabled }}[::]{{ end }}:{{ $root.Values.haproxy.containerPort }} ssl crt {{ .Values.haproxy.tls.certMountPath }}{{ .Values.haproxy.tls.keyName }} {{ if .Values.haproxy.IPv6.enabled }}v4v6{{ end }}
      {{ else }}
      bind {{ if .Values.haproxy.IPv6.enabled }}[::]{{ end }}:{{ if ne (int $root.Values.redis.port) 0 }}{{ $root.Values.redis.port }}{{ else }}{{ $root.Values.redis.tlsPort }}{{ end }} {{ if .Values.haproxy.IPv6.enabled }}v4v6{{ end }}
      {{- end }}
      use_backend bk_redis_master
    {{- if .Values.haproxy.readOnly.enabled }}
    #slave
    frontend ft_redis_slave
      bind {{ if .Values.haproxy.IPv6.enabled }}[::]{{ end }}:{{ .Values.haproxy.readOnly.port }} {{ if .Values.haproxy.IPv6.enabled }}v4v6{{ end }}
      use_backend bk_redis_slave
    {{- end }}
    # Check all redis servers to see if they think they are master
    backend bk_redis_master
      {{- if .Values.haproxy.stickyBalancing }}
      balance source
      hash-type consistent
      {{- end }}
      mode tcp
      option tcp-check
      tcp-check connect
      {{- if .Values.auth }}
      tcp-check send "AUTH ${AUTH}"\r\n
      tcp-check expect string +OK
      {{- end }}
      tcp-check send PING\r\n
      tcp-check expect string +PONG
      tcp-check send info\ replication\r\n
      tcp-check expect string role:master
      tcp-check send QUIT\r\n
      tcp-check expect string +OK
      {{- range $i := until $replicas }}
      use-server R{{ $i }} if { srv_is_up(R{{ $i }}) } { nbsrv(check_if_redis_is_master_{{ $i }}) ge 2 }
      {{- if $.Values.sentinel.resolveHostnames }}
      server R{{ $i }} {{ $fullName }}-announce-{{ $i }}.{{ $.Release.Namespace }}.svc:{{ $root.Values.redis.port }} check inter {{ $root.Values.haproxy.checkInterval }} fall {{ $root.Values.haproxy.checkFall }} rise 1
      {{- else }}
      server R{{ $i }} {{ $fullName }}-announce-{{ $i }}:{{ $root.Values.redis.port }} check inter {{ $root.Values.haproxy.checkInterval }} fall {{ $root.Values.haproxy.checkFall }} rise 1
      {{- end }}
      {{- end }}
    {{- if .Values.haproxy.readOnly.enabled }}
    backend bk_redis_slave
      {{- if .Values.haproxy.stickyBalancing }}
      balance source
      hash-type consistent
      {{- end }}
      mode tcp
      option tcp-check
      tcp-check connect
      {{- if .Values.auth }}
      tcp-check send "AUTH ${AUTH}"\r\n
      tcp-check expect string +OK
      {{- end }}
      tcp-check send PING\r\n
      tcp-check expect string +PONG
      tcp-check send info\ replication\r\n
      tcp-check expect  string role:slave
      tcp-check send QUIT\r\n
      tcp-check expect string +OK
      {{- range $i := until $replicas }}
      {{- if $.Values.sentinel.resolveHostnames }}
      server R{{ $i }} {{ $fullName }}-announce-{{ $i }}.{{ $.Release.Namespace }}.svc:{{ $root.Values.redis.port }} check inter {{ $root.Values.haproxy.checkInterval }} fall {{ $root.Values.haproxy.checkFall }} rise 1
      {{- else }}
      server R{{ $i }} {{ $fullName }}-announce-{{ $i }}:{{ $root.Values.redis.port }} check inter {{ $root.Values.haproxy.checkInterval }} fall {{ $root.Values.haproxy.checkFall }} rise 1
      {{- end }}
      {{- end }}
    {{- end }}
    {{- if .Values.haproxy.metrics.enabled }}
    frontend stats
      mode http
      bind {{ if .Values.haproxy.IPv6.enabled }}[::]{{ end }}:{{ .Values.haproxy.metrics.port }} {{ if .Values.haproxy.IPv6.enabled }}v4v6{{ end }}
      http-request use-service prometheus-exporter if { path {{ .Values.haproxy.metrics.scrapePath }} }
      stats enable
      stats uri /stats
      stats refresh 10s
    {{- end }}
{{- if .Values.haproxy.extraConfig }}
    # Additional configuration
{{ .Values.haproxy.extraConfig | indent 4 }}
{{- end }}
{{- end }}
{{- end }}


{{- define "config-haproxy_init.sh" }}
    HAPROXY_CONF=/data/haproxy.cfg
    cp /readonly/haproxy.cfg "$HAPROXY_CONF"
    {{- $fullName := include "redis-ha.fullname" . }}
    {{- $replicas := int (toString .Values.replicas) }}
    {{- $resolveHostnames := .Values.sentinel.resolveHostnames }}
    {{- $namespace := .Release.Namespace }}
    {{- range $i := until $replicas }}
    {{- if $resolveHostnames }}
    ANNOUNCE_IP{{ $i }}="{{ $fullName }}-announce-{{ $i }}.{{ $namespace }}.svc"
    echo "Using hostname for {{ $fullName }}-announce-{{ $i }}.{{ $namespace }}.svc: $ANNOUNCE_IP{{ $i }}"
    {{- else }}
    for loop in $(seq 1 10); do
      getent hosts {{ $fullName }}-announce-{{ $i }} && break
      echo "Waiting for service {{ $fullName }}-announce-{{ $i }} to be ready ($loop) ..." && sleep 1
    done
    ANNOUNCE_IP{{ $i }}=$(getent hosts "{{ $fullName }}-announce-{{ $i }}" | awk '{ print $1 }')
    if [ -z "$ANNOUNCE_IP{{ $i }}" ]; then
      echo "Could not resolve the announce address for {{ $fullName }}-announce-{{ $i }}"
      exit 1
    fi
    {{- end }}
    sed -i "s/REPLACE_ANNOUNCE{{ $i }}/$ANNOUNCE_IP{{ $i }}/" "$HAPROXY_CONF"

    {{- end }}
{{- end }}

{{- define "redis_liveness.sh" }}
    {{- if not (ne (int .Values.sentinel.port) 0) }}
    TLS_CLIENT_OPTION="--tls --cacert /tls-certs/{{ .Values.tls.caCertFile }}{{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{end}}"
    {{- end }}
    response=$(
      redis-cli \
      {{- if .Values.auth }}
        -a "${AUTH}" --no-auth-warning \
      {{- end }}
        -h localhost \
      {{- if ne (int .Values.redis.port) 0 }}
        -p {{ .Values.redis.port }} \
      {{- else }}
        -p {{ .Values.redis.tlsPort }} ${TLS_CLIENT_OPTION} \
      {{- end}}
        ping
    )
    echo "response=$response"
    case $response in
      PONG|LOADING*) ;;
      *) exit 1 ;;
    esac
    exit 0
{{- end }}

{{- define "sentinel_prestop.sh" }}
    {{- if eq (int .Values.redis.port) 0 }}
    TLS_CLIENT_OPTION="--tls --cacert /tls-certs/{{ .Values.tls.caCertFile }}{{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{end}}"
    {{- end }}
    redis_role() {
      redis-cli \
      {{- if .Values.auth }}
        -a "${AUTH}" --no-auth-warning \
      {{- end }}
        -h localhost \
      {{- if ne (int .Values.redis.port) 0 }}
        -p {{ .Values.redis.port }} \
      {{- else }}
        -p {{ .Values.redis.tlsPort }} ${TLS_CLIENT_OPTION} \
      {{- end}}
        role 2>/dev/null | head -n 1
    }
    # The redis container's preStop hook asks this sentinel to fail over.
    # Kubernetes stops both containers at once, so keep this sentinel running
    # until the local redis is no longer master.
    waited=0
    while [ "$waited" -lt 40 ] && [ "$(redis_role)" = "master" ]; do
      sleep 1
      waited=$((waited + 1))
    done
    if [ "$waited" -gt 0 ]; then
      # Give this sentinel time to publish the new configuration.
      sleep 5
    fi
{{- end }}

{{- define "redis_readiness.sh" }}
    {{- if not (ne (int .Values.sentinel.port) 0) }}
    TLS_CLIENT_OPTION="--tls --cacert /tls-certs/{{ .Values.tls.caCertFile }}{{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{end}}"
    {{- end }}
    response=$(
      redis-cli \
      {{- if .Values.auth }}
        -a "${AUTH}" --no-auth-warning \
      {{- end }}
        -h localhost \
      {{- if ne (int .Values.redis.port) 0 }}
        -p {{ .Values.redis.port }} \
      {{- else }}
        -p {{ .Values.redis.tlsPort }} ${TLS_CLIENT_OPTION} \
      {{- end}}
        ping
    )
    if [ "$response" != "PONG" ] ; then
      echo "ping=$response"
      exit 1
    fi

    response=$(
      redis-cli \
      {{- if .Values.auth }}
        -a "${AUTH}" --no-auth-warning \
      {{- end }}
        -h localhost \
      {{- if ne (int .Values.redis.port) 0 }}
        -p {{ .Values.redis.port }} \
      {{- else }}
        -p {{ .Values.redis.tlsPort }} ${TLS_CLIENT_OPTION} \
      {{- end}}
        role
    )
    role=$( echo "$response" | sed "1!d" )
    if [ "$role" = "master" ]; then
      echo "role=$role"
      exit 0
    elif [ "$role" = "slave" ]; then
      repl=$( echo "$response" | sed "4!d" )
      echo "role=$role; repl=$repl"
      if [ "$repl" = "connected" ]; then
        exit 0
      else
        exit 1
      fi
    else
      echo "role=$role"
      exit 1
    fi
{{- end }}

{{- define "sentinel_liveness.sh" }}
    {{- if not (ne (int .Values.sentinel.port) 0) }}
    TLS_CLIENT_OPTION="--tls --cacert /tls-certs/{{ .Values.tls.caCertFile }}{{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{end}}"
    {{- end }}
    response=$(
      redis-cli \
      {{- if .Values.sentinel.auth }}
        -a "${SENTINELAUTH}" --no-auth-warning \
      {{- end }}
        -h localhost \
      {{- if ne (int .Values.sentinel.port) 0 }}
        -p {{ .Values.sentinel.port }} \
      {{- else }}
        -p {{ .Values.sentinel.tlsPort }} ${TLS_CLIENT_OPTION} \
      {{- end}}
        ping
    )
    if [ "$response" != "PONG" ]; then
      echo "$response"
      exit 1
    fi
    echo "response=$response"
{{- end }}
