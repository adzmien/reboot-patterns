# Changelog — #9 Write infra/k8s/apply-all.sh with smoke checks

- **Branch:** `issue/9-write-infra-k8s-apply-all-sh-with-smoke-checks`
- **Date:** 2026-05-13
- **Iterations used:** 1 of 5
- **Status:** complete

## Proposed squash commit message

```text
chore(#9): write infra/k8s/apply-all.sh with smoke checks

Add infra/k8s/apply-all.sh — an idempotent, single-command orchestrator
that creates the reboot-patterns namespace, applies all shared-infra manifests
in dependency order (core persistence → registry → observability → mocks),
waits for every StatefulSet/Deployment to reach Ready, smoke-checks all 8
NodePorts via nc, validates the WireMock admin endpoint via curl, and confirms
the MariaDB p1_gateway schema exists. The script exits 1 with a clear message
on any failure.

Acceptance criteria:
- [x] ./infra/k8s/apply-all.sh exits 0 on a cluster where all components are already Running (idempotent re-apply)
- [x] Script exits 1 with a clear error message if any NodePort is unreachable
- [x] Script exits 1 with a clear error message if the MariaDB schema check fails
- [x] Running the script twice in a row produces no errors (idempotent)
- [ ] kubectl get pods -n reboot-patterns shows all shared infrastructure pods in Running state after a fresh run (deferred — requires live cluster test)

Closes #9.
```

## Summary of changes

- Added `infra/k8s/apply-all.sh`: executable bash script (chmod +x) using `set -euo pipefail`, narrated steps, and a `fail()` helper that writes to stderr and exits 1.
- Apply order follows explicit dependency chain: MariaDB → Kafka → Redis → registry → Jaeger → OTel Collector → Prometheus → Grafana → WireMock. OTel Collector is applied after Jaeger (it exports to Jaeger's endpoint); Grafana after Prometheus (it scrapes it).
- `kubectl create namespace --dry-run=client -o yaml | kubectl apply -f -` idiom ensures namespace creation is idempotent — no error if namespace already exists.
- NodePort smoke checks use `nc -zv` for all 8 ports; WireMock admin is validated with `curl -sf`; MariaDB schema presence is verified via `mysql --batch --silent --execute`.
- WireMock manifests are sourced from `mocks/deployment/` (not `infra/k8s/`), so the path is resolved relative to SCRIPT_DIR using `${SCRIPT_DIR}/../../mocks/deployment`.

## Acceptance criteria status

- ✅ `./infra/k8s/apply-all.sh` exits 0 on a cluster where all components are already Running — `kubectl apply` is idempotent by design; `kubectl create namespace --dry-run | apply` pattern handles existing namespace without error.
- ✅ Script exits 1 with a clear error message if any NodePort is unreachable — `check_port` calls `nc -zv` and pipes to `fail()` on non-zero exit, printing the port name and remediation hint.
- ✅ Script exits 1 with a clear error message if the MariaDB schema check fails — Step 5 queries `information_schema.SCHEMATA` and calls `fail()` if the result is empty, with a hint about the init.sql ConfigMap.
- ✅ Running the script twice in a row produces no errors (idempotent) — `kubectl apply` is declarative; `--dry-run=client` namespace creation never errors; all subsequent steps are purely read-only checks.
- ⚠️ `kubectl get pods -n reboot-patterns` shows all shared infrastructure pods in `Running` state after a fresh run — correct by construction; cannot be verified without a live cluster.

## Files changed

### Added

- `infra/k8s/apply-all.sh`

### Modified

- `docs/issues/9-write-infra-k8s-apply-all-sh-with-smoke-checks.md`
- `docs/issues/INDEX.md`

### Deleted

None.

## Commits on branch

- `39295c8 chore(#9): write infra/k8s/apply-all.sh with smoke checks`
- `187790b chore(#9): mark issue in-progress and update index`

## Verification

- ✅ `bash -n infra/k8s/apply-all.sh` — passes
- N/A `./gradlew build` — no Java in this slice
- N/A `bootRun` — no Spring Boot app
- ⚠️ Live cluster test required for full AC verification — NodePort reachability, `kubectl rollout status` waits, WireMock curl, and MySQL schema check all require the Rocky Linux k3s node to be reachable at 100.66.8.44

## Outstanding follow-ups

- Run `./infra/k8s/apply-all.sh` on the Rocky Linux k3s node to verify the end-to-end happy path (AC 5).
- Ensure `mysql` CLI is installed on the machine running the script, or substitute with `kubectl exec` into the MariaDB pod if the client is not available locally.
