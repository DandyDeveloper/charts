# Changelog

All notable changes to this Helm chart will be documented in this file.

This project follows [Conventional Commits](https://www.conventionalcommits.org/) and uses [release-please](https://github.com/googleapis/release-please) to automate version bumps and changelog entries. Each merge to `main` may open or update a release pull request; merging that PR triggers [chart-releaser-action](https://github.com/helm/chart-releaser-action) to package the chart, create a tagged GitHub Release, and update the Helm repository index on the `gh-pages` branch.

Releases prior to the introduction of this changelog (chart versions ≤ `4.35.10`) are recorded in the project's [git history](https://github.com/corva-ai/redis-ha/commits/main) and inherited from the upstream [DandyDeveloper/charts](https://github.com/DandyDeveloper/charts) repository. The breaking-change notes below were carried over from the upstream chart's `README.md`.

## Historical breaking changes (inherited from upstream)

## [5.0.0](https://github.com/corva-ai/redis-ha/compare/4.35.10...5.0.0) (2026-05-19)


### Features

* **configs.tpl:** add redispatch, tcp-smart-connect, and tcp-smart-accept options to HAProxy configuration for improved connection handling ([3d24bd7](https://github.com/corva-ai/redis-ha/commit/3d24bd7193ef853d31bb4766889e37622f642280))
* **README.md, templates, values.yaml:** update image tags and add HAProxy global config support ([330a338](https://github.com/corva-ai/redis-ha/commit/330a33815049ad82190777e59167191f2e93fe36))
* **redis-ha:** add high availability Redis setup with HAProxy ([82cd3b0](https://github.com/corva-ai/redis-ha/commit/82cd3b009e0a2911a93b08820d466c7905826913))
* **redis:** enhance failover handling with preStop hooks ([a8ed8de](https://github.com/corva-ai/redis-ha/commit/a8ed8defcff3191eb318026205e46cd1a69015ba))
* **values.yaml:** update HAProxy timeout settings for improved idle connection handling ([6527599](https://github.com/corva-ai/redis-ha/commit/6527599902cf05c3f950e51ed5bfb8c8e40fbba9))


### Bug Fixes

* **templates:** add validation for redis and sentinel password fields to ensure required values are provided when authentication is enabled ([88806ce](https://github.com/corva-ai/redis-ha/commit/88806ce8bcc3033c21403b88d681ae2d596c2224))
* **templates:** correct conditional checks for redis and sentinel ports to ensure proper TLS configuration ([88806ce](https://github.com/corva-ai/redis-ha/commit/88806ce8bcc3033c21403b88d681ae2d596c2224))


### Miscellaneous Chores

* force next release to 5.0.0 ([e82f26f](https://github.com/corva-ai/redis-ha/commit/e82f26fa17ff588756701b0f2ae460afa8673b22))

### 4.21.0 — Kubernetes deprecation (PSP → seccompProfile)

This version introduced the deprecation of PodSecurityPolicy and added `seccompProfile` fields to the security contexts (introduced in Kubernetes 1.19). See <https://kubernetes.io/docs/tutorials/security/seccomp/>.

As a result, from this version onwards Kubernetes versions older than 1.19 will fail to install without removing `.Values.containerSecurityContext.seccompProfile` and `.Values.haproxy.containerSecurityContext.seccompProfile` (if HAProxy is enabled). The 4.35.x fork now enforces this via `Chart.yaml: kubeVersion: ">= 1.25.0-0"`, so the breakage is no longer reachable on supported clusters.

### 4.0.0 — HAProxy sidecar prometheus-exporter removed

Starting with chart version `4.x`, the standalone HAProxy sidecar prometheus-exporter was removed in favour of the embedded [HAProxy metrics endpoint](https://github.com/haproxy/haproxy/tree/master/contrib/prometheus-exporter). When upgrading from a `3.x` release, drop any `haproxy.exporter` settings from your values file and configure `haproxy.metrics` instead.

### 3.0.0 — Redis management strategy simplified; RBAC removed

The 3.x line simplified the failover/election strategy so the chart could use the official [redis](https://hub.docker.com/_/redis/) images without bespoke RBAC. When upgrading from `>=2.0.1` to `>=3.0.0`, the stale `Role`, `RoleBinding`, and `ServiceAccount` objects left over from the 2.x line must be deleted manually — `helm upgrade` does not remove them.

### 4.14.9 — HAProxy port keys renamed (potential breaking change)

Introduced the ability to change the HAProxy Deployment container port independently of the Redis port. Two keys moved:

- Container port in `redis-haproxy-deployment.yaml` changed from `redis.port` to `haproxy.containerPort` (default `6379`).
- Service port in `redis-haproxy-service.yaml` changed from `redis.port` to `haproxy.servicePort` (default `6379`).

If you previously overrode `redis.port` to reroute HAProxy, migrate that override to `haproxy.containerPort` / `haproxy.servicePort`.
