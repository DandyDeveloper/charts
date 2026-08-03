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
    sentinel_get_master() {
    set +e
        if [ "$SENTINEL_PORT" -eq 0 ]; then
            if [ "$RESOLVE_HOSTNAMES" = true ]; then
                redis-cli -h "${SERVICE}" -p "${SENTINEL_TLS_PORT}" {{ if .Values.sentinel.auth }} -a "${SENTINELAUTH}" --no-auth-warning{{ end }} --tls --cacert /tls-certs/{{ .Values.tls.caCertFile }} {{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{ end }} sentinel get-master-addr-by-name "${MASTER_GROUP}" |\
                head -n 1 | grep -E '^\s*[a-zA-Z0-9.-]+\s*$'
            else
                redis-cli -h "${SERVICE}" -p "${SENTINEL_TLS_PORT}" {{ if .Values.sentinel.auth }} -a "${SENTINELAUTH}" --no-auth-warning{{ end }} --tls --cacert /tls-certs/{{ .Values.tls.caCertFile }} {{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{ end }} sentinel get-master-addr-by-name "${MASTER_GROUP}" |\
                head -n 1 | grep -E '((^\s*((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))\s*$)|(^\s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?s*$))'
            fi
        else
            if [ "$RESOLVE_HOSTNAMES" = true ]; then
                redis-cli -h "${SERVICE}" -p "${SENTINEL_PORT}" {{ if .Values.sentinel.auth }} -a "${SENTINELAUTH}" --no-auth-warning{{ end }} sentinel get-master-addr-by-name "${MASTER_GROUP}" |\
                head -n 1 | grep -E '^\s*[a-zA-Z0-9.-]+\s*$'
            else
                redis-cli -h "${SERVICE}" -p "${SENTINEL_PORT}" {{ if .Values.sentinel.auth }} -a "${SENTINELAUTH}" --no-auth-warning{{ end }} sentinel get-master-addr-by-name "${MASTER_GROUP}" |\
                head -n 1 | grep -E '((^\s*((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))\s*$)|(^\s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?s*$))'
            fi
        fi
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
        echo "  using sentinel ({{ template "redis-ha.fullname" . }}), sentinel group name ({{ template "redis-ha.masterGroupName" . }})"
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

    setup_defaults() {
        echo "Setting up defaults.."
        echo "  using statefulset index (${INDEX})"
        if [ "${INDEX}" = "0" ]; then
            echo "Setting this pod as master for redis and sentinel.."
            echo "  using announce (${ANNOUNCE_IP})"
            redis_update "${ANNOUNCE_IP}"
            sentinel_update "${ANNOUNCE_IP}"
            echo "  make sure ${ANNOUNCE_IP} is not a slave (slaveof no one)"
            sed -i "s/^.*slaveof.*//" "${REDIS_CONF}"
        else
            if [ "$RESOLVE_HOSTNAMES" = true ]; then
                echo "Getting redis master hostname.."
                echo "  blindly assuming (${SERVICE}-announce-0.${NAMESPACE}.svc) is master"
                DEFAULT_MASTER="${SERVICE}-announce-0.${NAMESPACE}.svc"
                echo "  identified redis (may be redis master) hostname (${DEFAULT_MASTER})"
            else
                echo "Getting redis master ip.."
                echo "  blindly assuming (${SERVICE}-announce-0) or (${SERVICE}-server-0) are master"
                DEFAULT_MASTER="$(getent_hosts 0 | awk '{ print $1 }')"
                if [ -z "${DEFAULT_MASTER}" ]; then
                    echo "Error: Unable to resolve redis master (getent hosts)."
                    exit 1
                fi
                echo "  identified redis (may be redis master) ip (${DEFAULT_MASTER})"
            fi
            echo "Setting default slave config for redis and sentinel.."
            echo "  using master address (${DEFAULT_MASTER})"
            redis_update "${DEFAULT_MASTER}"
            sentinel_update "${DEFAULT_MASTER}"
        fi
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
            if [ "$(redis_ping)" = "PONG" ]; then
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
            echo "Attempting to force failover (sentinel failover).."

            if [ "$SENTINEL_PORT" -eq 0 ]; then
                echo "  on sentinel (${SERVICE}:${SENTINEL_TLS_PORT}), sentinel grp (${MASTER_GROUP})"
                if redis-cli -h "${SERVICE}" -p "${SENTINEL_TLS_PORT}" {{ if .Values.sentinel.auth }} -a "${SENTINELAUTH}" --no-auth-warning{{ end }} --tls --cacert /tls-certs/{{ .Values.tls.caCertFile }} {{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{ end }} sentinel failover "${MASTER_GROUP}" | grep -q 'NOGOODSLAVE' ; then
                    echo "  $(date) Failover returned with 'NOGOODSLAVE'"
                    echo "Setting defaults for this pod.."
                    setup_defaults
                    return 0
                fi
            else
                echo "  on sentinel (${SERVICE}:${SENTINEL_PORT}), sentinel grp (${MASTER_GROUP})"
                if redis-cli -h "${SERVICE}" -p "${SENTINEL_PORT}" {{ if .Values.sentinel.auth }} -a "${SENTINELAUTH}" --no-auth-warning{{ end }} sentinel failover "${MASTER_GROUP}" | grep -q 'NOGOODSLAVE' ; then
                    echo "  $(date) Failover returned with 'NOGOODSLAVE'"
                    echo "Setting defaults for this pod.."
                    setup_defaults
                    return 0
                fi
            fi

            echo "Hold on for 10sec"
            sleep 10
            echo "We should get redis master's ip now. Asking (get-master-addr-by-name).."
            if [ "$SENTINEL_PORT" -eq 0 ]; then
                echo "  sentinel (${SERVICE}:${SENTINEL_TLS_PORT}), sentinel grp (${MASTER_GROUP})"
            else
                echo "  sentinel (${SERVICE}:${SENTINEL_PORT}), sentinel grp (${MASTER_GROUP})"
            fi
            MASTER="$(sentinel_get_master)"
            if [ "${MASTER}" ]; then
                echo "  $(date) Found redis master (${MASTER})"
                echo "Updating redis and sentinel config.."
                sentinel_update "${MASTER}"
                redis_update "${MASTER}"
            else
                echo "$(date) Error: Could not failover, exiting..."
                exit 1
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

{{- define "trigger-failover-if-master.sh" }}
    {{- if or (eq (int .Values.redis.port) 0) (eq (int .Values.sentinel.port) 0) }}
    TLS_CLIENT_OPTION="--tls --cacert /tls-certs/{{ .Values.tls.caCertFile }}{{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{end}}"
    {{- end }}
    get_redis_role() {
      is_master=$(
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
          info | grep -c 'role:master' || true
      )
    }
    get_redis_role
    if [[ "$is_master" -eq 1 ]]; then
      echo "This node is currently master, we trigger a failover."
      {{- $masterGroupName := include "redis-ha.masterGroupName" . }}
      response=$(
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
          SENTINEL failover {{ $masterGroupName }}
      )
      if [[ "$response" != "OK" ]] ; then
        echo "$response"
        exit 1
      fi
      timeout=30
      while [[ "$is_master" -eq 1 && $timeout -gt 0 ]]; do
        sleep 1
        get_redis_role
        timeout=$((timeout - 1))
      done
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

    # Announce services publish not-ready addresses; the headless ${SERVICE}
    # does not, so it stops resolving once every pod is unready.
    REPLICA_COUNT={{ .Values.replicas }}
    REDIS_ACTIVE_PORT="${REDIS_PORT}"
    [ "$REDIS_PORT" -eq 0 ] && REDIS_ACTIVE_PORT="${REDIS_TLS_PORT}"

    announce_info() {
    set +e
        if [ "$REDIS_PORT" -eq 0 ]; then
            redis-cli {{ if .Values.auth }} -a "${AUTH}" --no-auth-warning{{ end }} -h "$1" -p "${REDIS_TLS_PORT}" --tls --cacert /tls-certs/{{ .Values.tls.caCertFile }} {{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{ end }} info replication 2>/dev/null | sed 's/\r//'
        else
            redis-cli {{ if .Values.auth }} -a "${AUTH}" --no-auth-warning{{ end }} -h "$1" -p "${REDIS_PORT}" info replication 2>/dev/null | sed 's/\r//'
        fi
    set -e
    }

    announce_cmd() {
    set +e
        host="$1"; shift
        if [ "$REDIS_PORT" -eq 0 ]; then
            redis-cli {{ if .Values.auth }} -a "${AUTH}" --no-auth-warning{{ end }} -h "$host" -p "${REDIS_TLS_PORT}" --tls --cacert /tls-certs/{{ .Values.tls.caCertFile }} {{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{ end }} "$@"
        else
            redis-cli {{ if .Values.auth }} -a "${AUTH}" --no-auth-warning{{ end }} -h "$host" -p "${REDIS_PORT}" "$@"
        fi
    set -e
    }

    announce_sentinel_cmd() {
    set +e
        host="$1"; shift
        if [ "$SENTINEL_PORT" -eq 0 ]; then
            redis-cli {{ if .Values.sentinel.auth }} -a "${SENTINELAUTH}" --no-auth-warning{{ end }} -h "$host" -p "${SENTINEL_TLS_PORT}" --tls --cacert /tls-certs/{{ .Values.tls.caCertFile }} {{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{ end }} "$@"
        else
            redis-cli {{ if .Values.sentinel.auth }} -a "${SENTINELAUTH}" --no-auth-warning{{ end }} -h "$host" -p "${SENTINEL_PORT}" "$@"
        fi
    set -e
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
        _best_ip=$(getent hosts "$_best_host" | awk '{ print $1 }')
        echo "ERROR: no member holds the master role. Promoting ${_best_host} (replication offset ${_best_off})."
        announce_cmd "$_best_host" replicaof no one
        _i=0
        while [ "$_i" -lt "$REPLICA_COUNT" ]; do
            if [ "$_i" -ne "$_best" ] && [ -n "$_best_ip" ]; then
                announce_cmd "${SERVICE}-announce-${_i}" replicaof "$_best_ip" "$REDIS_ACTIVE_PORT"
            fi
            _i=$((_i + 1))
        done
        _i=0
        while [ "$_i" -lt "$REPLICA_COUNT" ]; do
            announce_sentinel_cmd "${SERVICE}-announce-${_i}" sentinel reset "${MASTER_GROUP}"
            _i=$((_i + 1))
        done
        echo "Promotion complete: ${_best_host} is now master."
        return 0
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
                    # masterless state, so heal here instead of waiting for peers'
                    # stale-master counters. Promotion stays offset-aware — a
                    # freshly replaced (empty) pod behind a stale sentinel record
                    # must not be promoted just because sentinel names it.
                    echo "Redis role is $ROLE but sentinel names this pod as master; checking whether the set is masterless"
                    confirm_masterless_and_heal || true
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
                if [ -z "${MASTER_ACTUAL_ROLE}" ] || [ "${MASTER_ACTUAL_ROLE}" = "master" ]; then
                    # healthy, or unreachable (sentinel's own down detection handles that)
                    STALE_MASTER_COUNT=0
                else
                    STALE_MASTER_COUNT=$((STALE_MASTER_COUNT + 1))
                    echo "WARNING: Sentinel names ${MASTER} as master but its actual role is '${MASTER_ACTUAL_ROLE}' (set may be masterless). Failure count: $STALE_MASTER_COUNT/$MAX_STALE_MASTER_FAILURES"
                    if [ "$STALE_MASTER_COUNT" -ge "$MAX_STALE_MASTER_FAILURES" ]; then
                        echo "ERROR: Sentinel-named master has not held the master role for $MAX_STALE_MASTER_FAILURES consecutive checks. Forcing a failover..."
                        if [ "$SENTINEL_PORT" -eq 0 ]; then
                            redis-cli -h "${SERVICE}" -p "${SENTINEL_TLS_PORT}" {{ if .Values.sentinel.auth }} -a "${SENTINELAUTH}" --no-auth-warning{{ end }} --tls --cacert /tls-certs/{{ .Values.tls.caCertFile }} {{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{ end }} sentinel failover "${MASTER_GROUP}" || true
                        else
                            redis-cli -h "${SERVICE}" -p "${SENTINEL_PORT}" {{ if .Values.sentinel.auth }} -a "${SENTINELAUTH}" --no-auth-warning{{ end }} sentinel failover "${MASTER_GROUP}" || true
                        fi
                        # SENTINEL FAILOVER returns -NOGOODSLAVE when no
                        # candidate looks fresh; promote directly instead.
                        sleep {{ .Values.splitBrainDetection.retryInterval }}
                        confirm_masterless_and_heal || true
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
                if [ "$SENTINEL_PORT" -eq 0 ]; then
                    redis-cli -h "${SERVICE}" -p "${SENTINEL_TLS_PORT}" {{ if .Values.sentinel.auth }} -a "${SENTINELAUTH}" --no-auth-warning{{ end }} --tls --cacert /tls-certs/{{ .Values.tls.caCertFile }} {{ if ne (default "yes" .Values.sentinel.authClients) "no"}} --cert /tls-certs/{{ .Values.tls.certFile }} --key /tls-certs/{{ .Values.tls.keyFile }}{{ end }} sentinel reset "${MASTER_GROUP}" || true
                else
                    redis-cli -h "${SERVICE}" -p "${SENTINEL_PORT}" {{ if .Values.sentinel.auth }} -a "${SENTINELAUTH}" --no-auth-warning{{ end }} sentinel reset "${MASTER_GROUP}" || true
                fi
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
