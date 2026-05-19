# Review Report — issue/12-fast-fail-error-handling-and-canonical-failure-test-infrastructure

**Branch:** `issue/12-fast-fail-error-handling-and-canonical-failure-test-infrastructure`
**Base:** `main`
**Merge-base SHA:** `0126258`
**Date:** 2026-05-20
**Review mode:** Whole branch
**Grilling depth:** Light

---

## Commits walked

- `b242f88` pattern(p1-gateway): add GatewayErrorHandler and p1 reset script
- `8db5ac0` pattern(p1-gateway): add changelog for issue 12

---

## Files walked

### Added
- `patterns/p1-gateway/src/main/java/com/reboot/patterns/p1/gateway/config/GatewayErrorHandler.java`
- `tests/p1-gateway/reset.sh`
- `docs/issues/changelogs/12-fast-fail-error-handling-and-canonical-failure-test-infrastructure.md` _(meta doc, no quiz)_

### Modified
_(none)_

### Deleted
_(none)_

---

## Questions, answers, and outcomes

### GatewayErrorHandler.java

**Q1 — cause chain**
> The `isDownstreamFailure()` method walks `getCause()` in a loop instead of just checking `ex instanceof NotFoundException` directly. Why is the loop necessary?

- User answered: **Spring Cloud Gateway wraps routing exceptions in ResponseStatusException, so the root cause is never the top-level exception** ✅
- Correct.

**Q2 — @Order**
> If the `@Order(-1)` annotation were removed from `GatewayErrorHandler`, what would the caller receive when a downstream service is unreachable?

- User answered: **An HTTP 503 with Content-Type: text/html — the Spring Boot Whitelabel Error Page** ✅
- Correct.

---

### tests/p1-gateway/reset.sh

**Q1 — BASH_SOURCE**
> `reset.sh` uses `${BASH_SOURCE[0]}` to compute `SCRIPT_DIR` rather than `$0`. Why does this matter for how the script is used?

- User answered: **$0 contains the interpreter path (e.g. /bin/bash) when a script is sourced, so BASH_SOURCE[0] is needed to get the actual file path** ✅
- Correct.

**Q2 — scoped deletion**
> `reset.sh` deletes WireMock stubs using `select(.metadata.pattern == "p1")` instead of deleting all stubs. What breaks if you replace that with a blanket DELETE of all stubs?

- User answered: **Stubs for other patterns (p2, p3, …) and the permanent cross-cutting stubs in mocks/stubs/ would be wiped, breaking tests for those patterns** ✅
- Correct.

---

### Synthesis

**Synthesis Q1 — package placement**
> A reviewer asks: "Why does `GatewayErrorHandler` sit in the `config` package alongside `RouteConfig`, rather than in a dedicated `error` or `handler` package?"

- User answered: The config package is scanned first by Spring, giving @Order(-1) a chance to register before DefaultErrorWebExceptionHandler ❌
- Correct answer: **CLAUDE.md beginner mode rule** — no new package until a second pattern subproject demonstrably needs it. Package scan order has no bearing on `@Order` precedence; ordering is resolved numerically at runtime after all beans are registered.

**Synthesis Q2 — self-healing discovery**
> The acceptance criteria include: "After `kubectl apply`, `GET /order/123` returns HTTP 200 again without restarting the gateway." Which component makes this self-healing work?

- User answered: **Spring Cloud Kubernetes Discovery re-queries the K8s API for service endpoints on each lb:// resolution** ✅
- Correct.

---

## Weak areas and suggested re-reads

**Weak area:** Package placement justification — the instinct to reason about Spring scan order is a plausible-but-wrong distractor. The actual rule is CLAUDE.md §12 (beginner mode): no new packages/abstractions until a second pattern needs them.

**Suggested re-reads:**
- `CLAUDE.md §12` (beginner mode) — applies every time a new class is added to any pattern subproject.
- `CLAUDE.md §8` (failure injection idioms) — for when `/generate-tests` runs against this commit; the bash script must use `kubectl delete service/order` and `fixedDelayMilliseconds` stubs exactly as specified.

---

## Pre-merge risks

1. **`@Order(-1)` collision** — if live cluster testing returns `text/html` on a 503, bump to `@Order(Integer.MIN_VALUE + 1)`. Assert `Content-Type: application/json` first in the bash test.
2. **`pipefail` not set in `reset.sh`** — if WireMock is down during reset, the `curl` pipeline silently succeeds. Low risk in practice.
3. **Hard-coded `NODE_IP="100.66.8.44"`** — will need updating if the K3s node changes.
4. **No live cluster verification yet** — `routing-and-failure.sh` has not been generated. The branch is code-complete but not behaviourally verified. Deferred to `/generate-tests` by design, but this is the blocker before the issue can be marked `done`.
