# Changelog — #4 Adapt and deploy Redis to reboot-patterns

- **Branch:** `issue/4-adapt-and-deploy-redis-to-reboot-patterns`
- **Date:** 2026-05-12
- **Iterations used:** 1 of 5
- **Status:** complete

## Proposed squash commit message

```text
feat(#4): adapt and deploy Redis to reboot-patterns

Add K8s Deployment and Service manifests under infra/k8s/redis/ adapted
from the com-clean-baseline source. Namespace changed to reboot-patterns,
image kept at redis:7.4, and --requirepass $(REDIS_PASSWORD) added as a
CLI arg so vanilla redis:7.4 enforces auth (the env var alone has no
effect without this arg). NodePort 30379 is reachable from Mac via
Tailscale IP 100.66.8.44 and all auth operations (PING, SET, GET) pass.

Acceptance criteria:
- [x] Redis pod is `Running` after `kubectl apply -f infra/k8s/redis/`
- [x] `redis-cli -h 100.66.8.44 -p 30379 -a abc@123 PING` returns `PONG`
- [x] `SET` and `GET` with the password succeed
- [x] `nc -zv 100.66.8.44 30379` succeeds from Mac

Closes #4.
```

## Summary of changes

- Created `infra/k8s/redis/01-secret.yaml` (gitignored per repo policy) — Secret holding `redis-password: YWJjQDEyMw==` (`abc@123`) with learning-only warning comment.
- Created `infra/k8s/redis/02-deployment.yaml` — Deployment using `redis:7.4`, pulling `REDIS_PASSWORD` from the secret, and passing `--appendonly yes --requirepass $(REDIS_PASSWORD)` as container args.
- Created `infra/k8s/redis/03-service.yaml` — NodePort Service exposing port 6379 on nodePort 30379.
- Applied all three manifests; pod reached `Running` in under 60 seconds.
- Verified PING/SET/GET and TCP connectivity from Mac via Tailscale IP.

## Acceptance criteria status

- ✅ Redis pod is `Running` after `kubectl apply -f infra/k8s/redis/`
- ✅ `redis-cli -h 100.66.8.44 -p 30379 -a abc@123 PING` returns `PONG`
- ✅ `SET` and `GET` with the password succeed
- ✅ `nc -zv 100.66.8.44 30379` succeeds from Mac

## Files changed

### Added
- `infra/k8s/redis/02-deployment.yaml` (gitignored secret excluded from git history)
- `infra/k8s/redis/03-service.yaml`
- `docs/issues/changelogs/4-adapt-and-deploy-redis-to-reboot-patterns.md`

### Modified
None.

### Deleted
None.

## Commits on branch

```
0087b31 pattern(infra-redis): adapt and deploy Redis to reboot-patterns
```

Note: `infra/k8s/redis/01-secret.yaml` exists on disk and is applied to the cluster but is excluded from git history by the `*-secret.yaml` rule in `.gitignore`, consistent with how mariadb and kafka were handled.

## Verification

- ✅ Redis pod Running — `kubectl get pods -n reboot-patterns -l app=redis` shows `1/1 Running`
- ✅ `redis-cli PING` → PONG — confirmed via `redis-cli -h 100.66.8.44 -p 30379 -a abc@123 PING`
- ✅ SET/GET with auth succeed — `SET testkey testval` → `OK`, `GET testkey` → `testval`
- ✅ `nc -zv 100.66.8.44 30379` succeeds — `Connection to 100.66.8.44 port 30379 [tcp/*] succeeded!`
- N/A `./gradlew build` — no Gradle module in this issue

## Outstanding follow-ups

None.
