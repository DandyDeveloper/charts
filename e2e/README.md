# Manual E2E

This suite validates graceful termination, failover behavior, and split-brain repair against a real Kubernetes cluster. It is intentionally manual-only; the GitHub workflow is `workflow_dispatch` and does not run on PRs or pushes.

## Local kind Run

```bash
E2E_CREATE_KIND_CLUSTER=true ./e2e/run.sh
```

The default release is `redis-ha-e2e` in namespace `redis-ha-e2e`. The runner installs the chart with `e2e/values.yaml`, starts a Redis writer pod through HAProxy, runs all scenarios, and stores logs under `.e2e/artifacts/`.

When `E2E_CREATE_KIND_CLUSTER=true` and `KUBECONFIG` is not already set, the runner writes an isolated kubeconfig at `.e2e/kubeconfig`.

The runner uses two workload phases:

- `workload-availability.log`: controlled Sentinel failover and graceful master deletion. This phase requires zero failed client operations.
- `workload-resilience.log`: hard master kill and split-brain scenarios. This phase allows a small failed-operation budget because these are destructive faults, but still verifies that the final Redis counter is not below the highest acknowledged write.

## Existing Cluster Run

```bash
kubectl config use-context <context>
E2E_ENABLE_KIND_PARTITION=false ./e2e/run.sh
```

Set `E2E_ENABLE_KIND_PARTITION=false` outside kind unless the cluster supports the kind-specific Docker/iptables partition scenario.

## Scenarios

- Controlled Sentinel failover.
- Graceful master pod deletion using the chart lifecycle hooks.
- Hard master pod kill with `--grace-period=0 --force`.
- Forced split-brain repair by promoting a replica with `REPLICAOF NO ONE`.
- kind-only network partition that isolates the current master, waits for a quorum failover, heals the partition, and verifies repair.

## Useful Overrides

```bash
E2E_NAMESPACE=redis-ha-e2e
E2E_RELEASE=redis-ha-e2e
E2E_FULLNAME=redis-ha-e2e
E2E_REPLICAS=3
E2E_ARTIFACT_DIR=.e2e/artifacts/manual
E2E_OPERATION_TIMEOUT_SECONDS=15
E2E_RESILIENCE_ALLOWED_FAILED_OPS=5
E2E_ENABLE_KIND_PARTITION=true
E2E_REQUIRE_KIND_PARTITION=false
E2E_KIND_NODE_IMAGE=kindest/node:v1.34.0
```

If you use a release name that does not contain `redis-ha`, set `E2E_FULLNAME` to the rendered Helm fullname.
