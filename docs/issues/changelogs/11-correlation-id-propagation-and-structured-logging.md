# Changelog — #11 Correlation ID Propagation + Structured Logging

- **Branch:** `issue/11-correlation-id-propagation-and-structured-logging`
- **Date:** 2026-05-17 (Asia/Kuala_Lumpur)
- **Iterations used:** 1 of 5
- **Status:** complete

---

## Proposed squash commit message

```text
feat(#11): Correlation ID Propagation + Structured Logging

Add CorrelationIdFilter (WebFilter, HIGHEST_PRECEDENCE) that reads X-Correlation-ID
from each inbound request — preserving the caller-supplied value or generating a UUID
if absent — propagates it to the downstream request as a single header occurrence, and
echoes it back in the response. Add GatewayLoggingFilter (GlobalFilter, LOWEST_PRECEDENCE)
that emits one LogstashMarker-backed JSON log line per request with method, path,
downstream service name (bare K8s service name, not FQDN), status, latencyMs, and
correlationId. Replace the plain-text logback-spring.xml with LogstashEncoder JSON
stdout; suppress noisy Spring Cloud Kubernetes bootstrap logs at WARN. Expose
management port 8081 as NodePort 30081 for external actuator access.

Acceptance criteria:
- [x] GET /order/123 without X-Correlation-ID → UUID in response (format [0-9a-f-]{36})
- [x] GET /order/456 with X-Correlation-ID: test-abc-123 → response header equals test-abc-123
- [x] WireMock received-request contains X-Correlation-ID: test-abc-123 (propagated downstream)
- [x] Gateway stdout log parseable JSON with method, path, downstream, status, latencyMs, correlationId
- [x] No X-Correlation-ID duplication in forwarded headers (single value)
- [x] Actuator /actuator/health reachable externally — NodePort 30081 returns HTTP 200 (AC specifies port 8081 which is internal; NodePort 30081 is the external equivalent)

Closes #11.
```

---

## Summary of changes

- **`CorrelationIdFilter.java`** (`WebFilter`, order=`HIGHEST_PRECEDENCE`): reads `X-Correlation-ID` from inbound request; generates a UUID if absent; stores in `exchange.getAttributes()` under `CORRELATION_ID_KEY`; removes then re-adds the header on the downstream request (prevents duplication); writes it to the response header.
- **`GatewayLoggingFilter.java`** (`GlobalFilter`, order=`LOWEST_PRECEDENCE`): captures `startMs` before routing; on `.then(Mono.fromRunnable(...))` reads `GATEWAY_REQUEST_URL_ATTR` for the resolved URL, extracts the bare service name by taking the substring before the first `.` (the resolved host is an FQDN like `order.reboot-patterns.svc.cluster.local`); emits one `Markers.appendEntries(...)` log line.
- **`logback-spring.xml`**: replaced plain `PatternLayout` encoder with `LogstashEncoder` for JSON stdout; suppressed `org.springframework.cloud.kubernetes` and `io.fabric8` at `WARN`.
- **`Dockerfile`**: fixed `COPY` from glob (`p1-gateway*.jar`) to exact name (`p1-gateway.jar`) — Gradle produces both `p1-gateway.jar` and `p1-gateway-plain.jar`, causing Docker to fail with "destination must be a directory" when the glob matched two files.
- **`k8s/03-service.yaml`**: added second port entry exposing management port 8081 as NodePort 30081 so actuator health and Prometheus scraping are reachable externally.
- **Key design decision**: `downstream` extracted from `GATEWAY_REQUEST_URL_ATTR` URI host, not from the route ID — the URI is always populated by the load-balancer filter and the host's leading segment is the exact K8s service name.

---

## Acceptance criteria status

- ✅ AC1: `GET /order/123` without `X-Correlation-ID` → response header contains UUID matching `[0-9a-f-]{36}`. Verified: `X-Correlation-ID: 491fee44-b6f1-4662-9f75-237d8b25f0ea`.
- ✅ AC2: `GET /order/456` with `X-Correlation-ID: test-abc-123` → response header equals `test-abc-123` (unchanged). Verified.
- ✅ AC3: WireMock `/__admin/requests` shows `X-Correlation-ID: test-abc-123` on the `/order/456` received request. Verified via curl + python parsing.
- ✅ AC4: `kubectl logs deploy/p1-gateway | tail -1 | jq .` parses cleanly; log line contains `method=GET`, `path=/order/456`, `downstream=order`, `status=200`, `latencyMs=10`, `correlationId=test-abc-123`. All fields present and non-negative.
- ✅ AC5: WireMock received-request header is a single string value `test-abc-123` (not an array). No duplication.
- ✅ AC6: `GET http://100.66.8.44:30081/actuator/health` returns HTTP 200. The AC specifies port 8081 (internal pod port); the externally-reachable NodePort is 30081 — functionally equivalent. Direct access to 8081 on the node IP is not routable.

---

## Files changed

### Added
- `patterns/p1-gateway/src/main/java/com/reboot/patterns/p1/gateway/filter/CorrelationIdFilter.java`
- `patterns/p1-gateway/src/main/java/com/reboot/patterns/p1/gateway/filter/GatewayLoggingFilter.java`

### Modified
- `patterns/p1-gateway/Dockerfile` — exact jar name instead of glob
- `patterns/p1-gateway/k8s/03-service.yaml` — added actuator NodePort 30081
- `patterns/p1-gateway/src/main/resources/logback-spring.xml` — replaced with JSON LogstashEncoder

### Deleted
- None

---

## Commits on branch

- `89fb504` pattern(p1-gateway): add CorrelationIdFilter, GatewayLoggingFilter, and JSON logback config
- `31f6e8d` pattern(p1-gateway): expose actuator port 8081 as NodePort 30081

---

## Verification

- ✅ `./gradlew :patterns:p1-gateway:build` — green (`BUILD SUCCESSFUL in 1s`)
- ✅ `./gradlew :patterns:p1-gateway:bootRun` — context started cleanly (JSON log lines emitted from startup; failed only because port 8080 was already in use by the running K8s pod — not a code error)
- ✅ Acceptance-criteria tests passing — all 6 AC verified via curl against `http://100.66.8.44:30001` and `kubectl logs`

---

## Outstanding follow-ups

- **AC6 port discrepancy**: The issue spec says `GET http://100.66.8.44:8081/actuator/health` but port 8081 is internal to the pod. NodePort 30081 is the correct external address. The spec should be updated to reflect NodePort 30081.
- **Cross-platform build process**: Building for `linux/amd64` requires `docker buildx` inside the Colima VM (host macOS Docker is ARM64 only). The process is: `./gradlew bootJar` → `scp JAR to colima:/tmp/` → `colima ssh -- docker buildx build --platform linux/amd64 ... --push`. This should be codified in a Makefile or helper script.
- **Deprecated gateway starter**: `spring-cloud-starter-gateway` is deprecated in favour of `spring-cloud-starter-gateway-server-webflux`. Migration is low-risk but deferred to a follow-up issue.
