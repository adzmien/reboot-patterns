# Adapt and deploy MariaDB to reboot-patterns

## Spec Reference

ISSUE-2 from `docs/specs/spec-curriculum-setup.md`

## What to build

Adapt MariaDB K8s manifests from `com-reboot/reboot-common-k8s/mariadb/` into `infra/k8s/mariadb/`. Change namespace to `reboot-patterns`. Replace init.sql to pre-create all 8 pattern schemas (`p1_gateway`, `p2_resilience`, `p3_outbox`, `p4_saga_choreography`, `p5_saga_orchestration`, `p6_cqrs`, `p7_idempotency_dlq`, `p8_observability`) and grant all privileges to `rebootuser`. Keep credentials (`rebootuser`/`abc@123`), image (`mariadb:11.4`), and PVC size (5Gi) unchanged. NodePort 30306 must be reachable from Mac via Tailscale IP `100.66.8.44`.

## Acceptance Criteria

- [ ] MariaDB pod is `Running` after `kubectl apply -f infra/k8s/mariadb/`
- [ ] `SHOW SCHEMAS` returns all 8 pattern schemas
- [ ] `rebootuser` can `CREATE TABLE` in `p1_gateway` (and each other schema) without errors
- [ ] `nc -zv 100.66.8.44 30306` succeeds from Mac
- [ ] Reapplying the manifests (`kubectl apply` again) is idempotent — no errors, pod does not restart

## Blocked by

- #1
