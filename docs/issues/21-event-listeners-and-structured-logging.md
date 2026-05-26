# Event Listeners + Structured Logging for Resilience4j

## Spec Reference
ISSUE-8 from `docs/specs/spec-p2-resilience.md`

## What to build

Register Resilience4j event listeners in `ResilienceConfig` that emit a structured JSON log line for every significant resilience event. Service code stays clean — all observability wiring lives in `ResilienceConfig`.

**Listeners to register:**
- `CircuitBreaker`: `onSuccess`, `onError`, `onTimeout`, `onCallNotPermitted`, `onStateTransition`
- `Retry`: `onRetry`, `onSuccess`, `onError`
- `TimeLimiter`: `onTimeout`, `onSuccess`
- `Bulkhead`: `onCallRejected`, `onCallFinished`

**Required JSON fields per event** (use Logstash `kv()` markers, consistent with p1-gateway log fields):

| Field | Example value |
|---|---|
| `dependency` | `"payment"` (always) |
| `outcome` | `"success"`, `"timeout"`, `"circuit_open"`, `"retry"`, `"bulkhead_rejected"`, `"state_transition"` |
| `attemptCount` | number (where available from the event) |
| `latencyMs` | elapsed duration in ms (where available) |
| `correlationId` | from `MDC.get("correlationId")` |
| `from` | previous CB state (state transition events only) |
| `to` | new CB state (state transition events only) |

## Acceptance Criteria

- [ ] A healthy `POST /orders` produces a log line with `outcome=success`, `dependency=payment`, and `correlationId` matching the inbound `X-Correlation-ID` header
- [ ] A timed-out call produces a log line with `outcome=timeout`
- [ ] The circuit breaker opening produces a log line with `from=CLOSED`, `to=OPEN`
- [ ] A retry produces a log line with `outcome=retry` and `attemptCount` > 1
- [ ] A bulkhead rejection produces a log line with `outcome=bulkhead_rejected`
- [ ] No log line is missing `correlationId` when the header was supplied by the caller

Verify all criteria via `kubectl logs` during manual curl testing before marking done.

## Blocked by

- #20
