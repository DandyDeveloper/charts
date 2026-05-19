# AGENTS.md

Orientation for AI coding agents working in this repository.

## What this repo is

A Helm chart that deploys a highly-available Redis topology on Kubernetes: a `StatefulSet` of Redis master/replica pods, a Sentinel sidecar in each pod for failover management, an optional HAProxy fronting Redis, and an optional `redis_exporter` sidecar for Prometheus.

This is a maintained fork of `DandyDeveloper/charts/redis-ha`. Upstream is unmaintained; we track Redis releases and ship targeted fixes here.

## Layout

The chart lives at the repository root (it is _not_ nested under `charts/`):

- `Chart.yaml` — chart metadata. `appVersion` should track the Redis image tag in `values.yaml` (`image.tag`). Bump `version` on every user-visible change.
- `values.yaml` — the single source of truth for defaults and `helm-docs` parameter descriptions (the `# --` comments above keys feed the README parameter tables).
- `templates/` — chart templates. Resources are split by component:
  - `redis-ha-*.yaml` — Redis StatefulSet, services (including the announce service), ConfigMaps, RBAC, NetworkPolicy, PDB, ServiceMonitor, PrometheusRule.
  - `redis-haproxy-*.yaml` — HAProxy Deployment and friends (only rendered when `haproxy.enabled`).
  - `_helpers.tpl`, `_configs.tpl` — shared template helpers and the rendered Redis/Sentinel/HAProxy config blocks.
  - `tests/` — `helm test` hooks.
- `ci/` — values files exercised by `ct` (chart-testing) for CI lint/install runs.
- `README.md` — **generated** by [`helm-docs`](https://github.com/norwoodj/helm-docs) from `README.md.gotmpl` plus `values.yaml`. Do not hand-edit the parameter tables; edit `values.yaml` descriptions and re-run `helm-docs`. Prose above the tables is edited via `README.md.gotmpl`.
- `LICENSE` — Apache 2.0 inherited from upstream.

## Common workflows

```bash
# Lint
helm lint .

# Render with defaults
helm template my-release .

# Render with a CI values file (e.g. HAProxy enabled)
helm template my-release . -f ci/haproxy-enabled-values.yaml

# Regenerate README parameter tables after editing values.yaml
helm-docs
```

A `chart-testing` (`ct`) run against the files in `ci/` is the closest thing to integration coverage; install jobs require a real Kubernetes cluster (e.g. kind). The CI workflow runs `ct lint` on every PR and `ct install` on a kind cluster when chart files change.

### CI and release flow

GitHub Actions workflows in `.github/workflows/`:

- **`lint.yml`** — on every PR and push to `main`: `helm lint`, `ct lint` (config in `.ct.yaml`), and a `helm-docs` drift check that fails CI if `README.md` is stale relative to `values.yaml` / `README.md.gotmpl`.
- **`test.yml`** — on every PR: spins up a kind cluster and runs `ct install` against the chart and the values files in `ci/`. Only runs when chart files actually changed (per `ct list-changed`).
- **`release-please.yml`** — on push to `main`: runs [`googleapis/release-please-action`](https://github.com/googleapis/release-please) with config at `.github/release-please-config.json` and manifest at `.github/.release-please-manifest.json`. It opens (and keeps updated) a release PR that bumps `Chart.yaml: version` and appends `CHANGELOG.md` based on Conventional Commit history. `skip-github-release` is `true`, so release-please does **not** tag or release on its own.
- **`release.yml`** — on push to `main` when `Chart.yaml` changes, or by manual `workflow_dispatch`: packages the root-level chart into `.cr-release-packages/`, then runs [`helm/chart-releaser-action`](https://github.com/helm/chart-releaser-action) with packaging skipped so chart-releaser uploads that explicit package and updates `gh-pages`. `cr.yaml` keeps chart-releaser tags aligned with release-please's bare semver tags. GitHub Pages serves `gh-pages` as the Helm repository (`https://corva-ai.github.io/redis-ha`).

End-to-end: merge a `feat:`/`fix:` PR → release-please opens a "chore(main): release X.Y.Z" PR → merging that PR triggers `release.yml` → new tag, GitHub Release, and `gh-pages` index update appear automatically.

One-time setup the workflows assume:
- Repository **Settings → Actions → General → Workflow permissions** is set to "Read and write" so release-please can open PRs and chart-releaser can create releases.
- **Settings → Pages** serves from the `gh-pages` branch (`/` root). chart-releaser-action creates this branch on first run if it doesn't exist.

### Pre-commit

`.pre-commit-config.yaml` wires up `helm-docs`, `helm lint`, and a few hygiene hooks. Bootstrap once with:

```bash
pip install pre-commit  # or: brew install pre-commit
pre-commit install
```

After that, the README is regenerated automatically on every commit that touches `values.yaml`, `Chart.yaml`, or `README.md.gotmpl`. To run all hooks against the whole tree (useful in CI or after a big change), use `pre-commit run --all-files`.

## Conventions

- **Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/).** Format: `<type>(<optional scope>): <subject>`. Common `<type>` values in this repo: `feat`, `fix`, `chore`, `docs`, `refactor`, `build`, `ci`, `test`, `perf`. Scope is optional but useful when the change is component-specific (e.g. `feat(haproxy): …`, `fix(sentinel): …`). Keep the subject in the imperative mood and under ~72 characters; put rationale and breaking-change notes in the body.
- **Versioning is automated.** Do **not** hand-edit `Chart.yaml: version` or `CHANGELOG.md` in feature PRs — release-please owns both. Write Conventional Commit messages (`feat:` → minor bump, `fix:` → patch, `feat!:`/`BREAKING CHANGE:` → major), merge to `main`, and release-please opens a release PR that bumps the version and updates the changelog.
- **`appVersion` and `image.tag` move together.** `Chart.yaml: appVersion` and `values.yaml: image.tag` must agree (ignoring image-flavor suffixes like `-alpine`/`-bookworm`/`-debian`). Both carry inline `# renovate: datasource=docker depName=library/redis` hints so the `renovate.json` `customManagers` regex bumps them in lockstep. The `lint.yml` workflow's *Check appVersion ↔ image.tag drift* step is the backstop for manual PRs — bumping one without the other fails CI. Same convention applies for `haproxy.image.tag` and `exporter.tag`, which Renovate tracks independently (their `depName` differs from Redis, so they don't need a corresponding `appVersion`).
- **Docs stay in sync.** If you change `values.yaml` defaults or `# --` descriptions, regenerate the README. If you only changed prose, edit `README.md.gotmpl` and regenerate. Never edit the autogenerated table region of `README.md` directly — it will be overwritten.
- **HAProxy paths are optional.** Anything under `haproxy.*` only renders when `haproxy.enabled: true`. The CI values file `ci/haproxy-enabled-values.yaml` is the canonical example.
- **No upstream chart dependencies.** This chart is standalone (no `Chart.lock`, no subcharts). Don't add a `dependencies:` block unless explicitly required.
- **Backwards compatibility.** Existing users upgrade in place. Avoid renaming top-level value keys or template resource names without a clearly documented migration note in the README's _Upgrading the Chart_ section.
- **Security context defaults are restrictive** (non-root, `seccompProfile: RuntimeDefault`, dropped capabilities). Preserve those defaults; do not loosen them to make a change work — fix the underlying issue.

## Things to avoid

- Hand-editing the parameter tables in `README.md`. They are regenerated.
- Adding the chart back under a `charts/<name>/` subdirectory — this repo's layout is intentionally flat (one chart per repo).
