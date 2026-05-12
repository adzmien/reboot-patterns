# Adapt and deploy Redis to reboot-patterns
Status: done 2026-05-12

## Spec Reference

ISSUE-4 from `docs/specs/spec-curriculum-setup.md`

## What to build

Adapt Redis K8s manifests from `com-reboot/reboot-common-k8s/redis/` into `infra/k8s/redis/`. Change namespace to `reboot-patterns`. Keep credentials (`abc@123`), image (`redis:7.4`), and config (`--appendonly yes`, `--requirepass`) unchanged. NodePort 30379 must be reachable from Mac via Tailscale IP `100.66.8.44`.

## Acceptance Criteria

- [ ] Redis pod is `Running` after `kubectl apply -f infra/k8s/redis/`
- [ ] `redis-cli -h 100.66.8.44 -p 30379 -a abc@123 PING` returns `PONG`
- [ ] `SET` and `GET` with the password succeed
- [ ] `nc -zv 100.66.8.44 30379` succeeds from Mac

## Blocked by

None — can start immediately
