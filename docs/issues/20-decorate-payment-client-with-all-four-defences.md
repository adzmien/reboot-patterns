# Decorate PaymentClient with All Four Resilience4j Defences

## Spec Reference
ISSUE-7 from `docs/specs/spec-p2-resilience.md`

## What to build

Wrap `PaymentClient.requestPayment()` with all four Resilience4j defences in the correct decoration order and map each failure mode to a typed `PaymentResult`. After this issue, every success criterion in the PD (timeout, fast-fail, half-open, bulkhead rejection) is manually verifiable with curl.

**Decoration order** (CB outermost, Bulkhead innermost):
```
CircuitBreaker → Retry → TimeLimiter → Bulkhead → RestTemplate call
```
Each retry attempt counts as a separate circuit breaker window entry — this is intentional and speeds up test scenarios.

**MDC propagation:** `TimeLimiter` submits the call to a `ScheduledExecutorService`. Before submitting, capture `MDC.getCopyOfContextMap()` and restore it inside the `Callable` so `correlationId` is not lost on the executor thread.

**Typed failure mapping:**
- `CallNotPermittedException` → `PaymentResult.circuitOpen()`
- `TimeoutException` → `PaymentResult.unavailable()`
- `BulkheadFullException` → `PaymentResult.capacityExhausted()`

`OrderController` maps these to `503` with bodies:
- `{"error": "circuit_open"}`
- `{"error": "payment_unavailable"}`
- `{"error": "capacity_exhausted"}`

## Acceptance Criteria

- [ ] With WireMock stub delay 1500ms, `POST /orders` returns `503 {"error":"payment_unavailable"}` in approximately 1100ms (timeout fires at 1s)
- [ ] After 5 calls all timing out, the 6th call returns `503 {"error":"circuit_open"}` in under 50ms (no WireMock request made)
- [ ] With a healthy stub, `POST /orders` returns `200 {"status":"ACCEPTED"}`
- [ ] With 15 concurrent `POST /orders` requests, at least 5 return `503 {"error":"capacity_exhausted"}`
- [ ] `GET http://localhost:30080/__admin/requests` shows `X-Correlation-ID` present on every payment request, including retry attempts

## Blocked by

- #18
- #19
