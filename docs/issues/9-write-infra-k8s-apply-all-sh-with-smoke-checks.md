# Write infra/k8s/apply-all.sh with smoke checks

Status: in-progress 2026-05-13

## Spec Reference

ISSUE-9 from `docs/specs/spec-curriculum-setup.md`

## What to build

Write `infra/k8s/apply-all.sh` that orchestrates the full shared infrastructure setup in one command: (1) create/ensure `reboot-patterns` namespace, (2) apply all manifests in dependency order (core infra → registry → observability → mocks), (3) wait for each StatefulSet and Deployment to reach Ready state via `kubectl rollout status`, (4) run smoke checks for all NodePorts (`nc -zv 100.66.8.44` for ports 30306, 30092, 30379, 30080, 30686, 30090, 30030, 30500), `curl -sf http://100.66.8.44:30080/__admin/mappings`, and a MySQL schema existence check. Script exits 1 loudly on any failure. Running this script successfully is the definition-of-done gate for US-1.

## Acceptance Criteria

- [ ] `./infra/k8s/apply-all.sh` exits 0 on a cluster where all components are already Running (idempotent re-apply)
- [ ] Script exits 1 with a clear error message if any NodePort is unreachable
- [ ] Script exits 1 with a clear error message if the MariaDB schema check fails
- [ ] Running the script twice in a row produces no errors (idempotent)
- [ ] `kubectl get pods -n reboot-patterns` shows all shared infrastructure pods in `Running` state after a fresh run

## Blocked by

- #2, #3, #4, #5, #6, #7, #8
