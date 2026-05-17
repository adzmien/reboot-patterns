# Correlation ID Propagation + Structured Logging

## Spec Reference

ISSUE-3 from `docs/specs/spec-p1-gateway.md`

## What to build

Every request through the gateway carries an `X-Correlation-ID` header (generated as a UUID if absent, preserved if present) and the gateway emits one JSON log line per request — parseable with `jq` — containing method, path, downstream service name, HTTP status, latency in ms, and correlationId.

**`CorrelationIdFilter.java`** — `WebFilter` ordered before routing:
- Reads `X-Correlation-ID` from the inbound request; generates a UUID if absent
- Stores the value in `ServerWebExchange` attributes under a constant key `CORRELATION_ID_KEY`
- Mutates the downstream request headers to include the value (single occurrence — no duplication)
- Writes the value back to the response header so callers see it

**`GatewayLoggingFilter.java`** — `GlobalFilter` ordered after routing (use `Ordered.LOWEST_PRECEDENCE` and chain on `exchange.getResponse().beforeCommit(...)` to capture status code after the downstream responds):
- Reads the downstream service ID from `ServerWebExchange` route attributes
- Reads `CORRELATION_ID_KEY` from exchange attributes
- Captures pre/post timestamps for latency calculation
- Emits one `LogstashMarker`-backed log line on response completion with fields: `method`, `path`, `downstream`, `status`, `latencyMs`, `correlationId`

**`logback-spring.xml`** — single JSON stdout appender using `LogstashEncoder`; root log level `INFO`; noisy Spring Cloud Kubernetes bootstrap logs suppressed at `WARN`.

## Acceptance Criteria

- [ ] `GET /order/123` without `X-Correlation-ID` header → response includes `X-Correlation-ID` header with a value matching UUID format (`[0-9a-f-]{36}`)
- [ ] `GET /order/456` with `X-Correlation-ID: test-abc-123` → response `X-Correlation-ID` header equals `test-abc-123` (unchanged)
- [ ] WireMock received-request for the above call contains request header `X-Correlation-ID: test-abc-123` (verified via `GET http://100.66.8.44:30080/__admin/requests`)
- [ ] Gateway stdout log contains a parseable JSON line with fields `method`, `path`, `downstream`, `status`, `correlationId`, and a non-negative integer `latencyMs` (verified with `kubectl logs deploy/p1-gateway -n reboot-patterns | tail -1 | jq .`)
- [ ] No `X-Correlation-ID` duplication in forwarded headers (single value, not doubled)
- [ ] `GET http://100.66.8.44:8081/actuator/health` returns HTTP 200 (actuator reachable on management port)

## Blocked by

- #10
