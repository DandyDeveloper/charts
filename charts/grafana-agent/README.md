# Grafana Agent

[Grafana Agent](https://grafana.com/docs/agent/latest/) is an alternative to Prometheus specifically crafted for remote writes. Grafana Agent removes the fluff from Prometheus to provide a more compact experience with Prometheus. 

## TL;DR

```bash
helm repo add dandydev https://dandydeveloper.github.io/charts
helm install dandydev/grafana-agent
```

By default, this chart will install a DaemonSet across all nodes. Those agents will scrape the metrics from the local node and its resources. 

## Introduction

This chart bootstraps a [Grafana Agent](https://grafana.com/docs/agent/latest/).

## Prerequisites

* Kubernetes 1.15+
* PV provisioner support in the underlying infrastructure (if scrapingService.enabled)

## Installing the Chart

To install the chart

```bash
helm repo add dandydev https://dandydeveloper.github.io/charts
helm install dandydev/grafana-agent
```

## Uninstalling the Chart

To uninstall/delete the deployment:

```bash
helm delete <Release Name>
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

The following table lists the configurable parameters of the Grafana Agent chart and their default values.

| Parameter                 | Description                                                                                                                                          | Default                                                                        |
|:--------------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------|:-------------------------------------------------------------------------------|
| `image.repository`        | Grafana Agent image                                                                                                                                  | `grafana/agent`                                                                |
| `image.pullPolicy`        | Image pull policy                                                                                                                                    | `IfNotPresent`                                                                 |
| `image.tag`               | Grafana Agent tag                                                                                                                                    | ``                                                                             |
| `imagePullSecrets`        | Pull secret for private repository                                                                                                                   | []                                                                             |
| `nameOverride`            | Release name override                                                                                                                                | ``                                                                             |
| `fullnameOverride`        | Full name overrie for release                                                                                                                        | ``                                                                             |
| `serviceAccount.create`   | Specifies whether a ServiceAccount should be created                                                                                                 | `true`                                                                         |
| `serviceAccount.name`     | The name of the ServiceAccount to create                                                                                                             | Generated using the grafana-agent.fullname template                            |
| `serviceAccount.annorations` | Service Account annotations                                                                                                                       | `{}`                                                                           |
| `replicaCount`            | Number of replicas of Grafana Agent deployment (only relevant for service scraping mode)                                                             | `3`                                                                            |
| `podAnnorations`          | Pod annotations                                                                                                                                      | `{}`                                                                           |
| `podSecurityContext`      | Pod Security Context                                                                                                                                 | `{}`                                                                           |
| `securityContext.privileged` | Run as privileged user                                                                                                                            | `true`                                                                         |
| `service.type`            | Service Type                                                                                                                                         | `ClusterIP`                                                                    |
| `service.port`            | Kubernetes service port                                                                                                                              | `80`                                                                           |
| `resources`               | Kubernetes pod resources                                                                                                                             | `{}`                                                                           |
| `nodeSelector`            | Pod node selector                                                                                                                                    | `{}`                                                                           |
| `config.prometheus.walDir`                  | Directory mount point for Grafana Agent WAL                                                                                                          | `/var/lib/agent/data`                                                          |
| `config.prometheus.remoteWrite.url`         | URL for the upstream federated Prometheus / Cortex instance                                                                                          | `""`                                                                           |
| `config.prometheus.remoteWrite.auth.username` | Remote write username                                                                                                                              | `nil`                                                                          |
| `config.prometheus.remoteWrite.auth.password` | Remote write password                                                                                                                              | `nil`                                                                          |
| `config.prometheus.scrapeInterval`   | Global scrape interval                                                                                                                               | `15s`                                                                          |
| `config.prometheus.externalLabels`   | External labels                                                                                                                                      | `{}`                                                                           |
| `config.prometheus.configs`| Scrape configs / General configs for the Prometheus scraping                                                                                         | `[]`                                                                           |
| `scrapingServiceMode.enabled` | Enabled scraping service mode. See below for more details                                                                                        | `false`                                                                        |

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```bash
$ helm repo add dandydev https://dandydeveloper.github.io/charts
$ helm install \
  --set tag=1.7.0 \
    dandydev/grafana-agent
```

The above command sets the Redis server within `default` namespace.

Alternatively, a YAML file that specifies the values for the parameters can be provided while installing the chart. For example,

```bash
helm install -f values.yaml dandydev/redis-ha
```

> **Tip**: You can use the default [values.yaml](values.yaml) 

# Scraping Service Mode
