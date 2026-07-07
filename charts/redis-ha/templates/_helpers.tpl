{{/* vim: set filetype=mustache: */}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "redis-ha.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "redis-ha.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{/*
Return sysctl image
*/}}
{{- define "redis.sysctl.image" -}}
{{- $registryName :=  default "docker.io" .Values.sysctlImage.registry -}}
{{- $tag := default "latest" .Values.sysctlImage.tag | toString -}}
{{- printf "%s/%s:%s" $registryName .Values.sysctlImage.repository $tag -}}
{{- end -}}

{{- /*
Credit: @technosophos
https://github.com/technosophos/common-chart/
labels.standard prints the standard Helm labels.
The standard labels are frequently used in metadata.
*/ -}}
{{- define "labels.standard" -}}
app: {{ template "redis-ha.name" . }}
heritage: {{ .Release.Service | quote }}
release: {{ .Release.Name | quote }}
chart: {{ template "chartref" . }}
{{- end -}}

{{- /*
Credit: @technosophos
https://github.com/technosophos/common-chart/
chartref prints a chart name and version.
It does minimal escaping for use in Kubernetes labels.
Example output:
  zookeeper-1.2.3
  wordpress-3.2.1_20170219
*/ -}}
{{- define "chartref" -}}
  {{- replace "+" "_" .Chart.Version | printf "%s-%s" .Chart.Name -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "redis-ha.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "redis-ha.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "redis-ha.masterGroupName" -}}
{{- $masterGroupName := tpl ( .Values.redis.masterGroupName | default "") . -}}
{{- $validMasterGroupName := regexMatch "^[\\w-\\.]+$" $masterGroupName -}}
{{- if $validMasterGroupName -}}
{{ $masterGroupName }}
{{- else -}}
{{ required "A valid .Values.redis.masterGroupName entry is required (matching ^[\\w-\\.]+$)" ""}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for poddisruptionbudget.
*/}}
{{- define "redis-ha.podDisruptionBudget.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "policy/v1" }}
{{- print "policy/v1" -}}
{{- else -}}
{{- print "policy/v1beta1" -}}
{{- end -}}
{{- end -}}

{{/* 
Return true if the detected platform is Openshift
Usage:
{{- include "common.compatibility.isOpenshift" . -}}
*/}}
{{- define "compatibility.isOpenshift" -}}
{{- if .Capabilities.APIVersions.Has "security.openshift.io/v1" -}}
{{- true -}}
{{- end -}}
{{- end -}}

{{/*
Render a compatible securityContext depending on the platform. By default it is maintained as it is. In other platforms like Openshift we remove default user/group values that do not work out of the box with the restricted-v1 SCC
Usage:
{{- include "compatibility.renderSecurityContext" (dict "secContext" .Values.containerSecurityContext "context" $) -}}
*/}}
{{- define "compatibility.renderSecurityContext" -}}
{{- $adaptedContext := .secContext -}}

{{- if (((.context.Values.global).compatibility).openshift) -}}
  {{- if or (eq .context.Values.global.compatibility.openshift.adaptSecurityContext "force") (and (eq .context.Values.global.compatibility.openshift.adaptSecurityContext "auto") (include "compatibility.isOpenshift" .context)) -}}
    {{/* Remove incompatible user/group values that do not work in Openshift out of the box */}}
    {{- $adaptedContext = omit $adaptedContext "fsGroup" "runAsUser" "runAsGroup" -}}
    {{- if not .secContext.seLinuxOptions -}}
    {{/* If it is an empty object, we remove it from the resulting context because it causes validation issues */}}
    {{- $adaptedContext = omit $adaptedContext "seLinuxOptions" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{/* Remove fields that are disregarded when running the container in privileged mode */}}
{{- if $adaptedContext.privileged -}}
  {{- $adaptedContext = omit $adaptedContext "capabilities" "seLinuxOptions" -}}
{{- end -}}
{{- omit $adaptedContext "enabled" | toYaml -}}
{{- end -}}

{{/*
Defines the redis ports to be used inside network policies
Usage:
{{- include "redis-ports" . -}}
*/}}
{{- define "redis-ports" -}}
{{- if ne (int .Values.redis.port) 0 }}
- port: {{ .Values.redis.port }}
  protocol: TCP
{{- end -}}
{{- if ne (int .Values.sentinel.port) 0 }}
- port: {{ .Values.sentinel.port }}
  protocol: TCP
{{- end -}}
{{- if ne (int .Values.redis.tlsPort) 0 }}
- port: {{ .Values.redis.tlsPort }}
  protocol: TCP
{{- end -}}
{{- if ne (int .Values.sentinel.tlsPort) 0 }}
- port: {{ .Values.sentinel.tlsPort }}
  protocol: TCP
{{- end -}}
{{- end -}}

{{/*
Name of the "data" volume mounted at /data across the StatefulSet's containers.

This value is used in two tied roles that MUST stay in sync:
  1. The volume identifier referenced by every volumeMount in the StatefulSet.
  2. The volumeClaimTemplates name, which Kubernetes uses as the PVC name prefix:
     <dataVolumeName>-<statefulset-name>-<ordinal>  (e.g. data-my-redis-server-0)

It also names the hostPath/emptyDir volume when persistentVolume.enabled is false,
so the mounts resolve regardless of the backing store.
*/}}
{{- define "redis-ha.dataVolumeName" -}}
{{- default "data" .Values.dataVolumeOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Name of the Redis server StatefulSet: the fullname plus the configurable
.Values.statefulSetSuffix (default "server", giving the historical <fullname>-server).

This is a single source of truth for the StatefulSet name, because the same
value has to appear in more than one place or the cluster breaks:
  1. The StatefulSet's own metadata.name.
  2. The per-pod announce Services, whose "statefulset.kubernetes.io/pod-name"
     selector must equal <statefulSetName>-<ordinal> to target the right pod. If it
     drifts from the StatefulSet name, those Services select nothing.
*/}}
{{- define "redis-ha.statefulSetName" -}}
{{- printf "%s-%s" (include "redis-ha.fullname" .) .Values.statefulSetSuffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}
