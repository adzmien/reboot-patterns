# Grilling Context Dossier

## 1. Source PD
- Location: https://www.notion.so/PD-Resilience-p2-resilience-07514e023ce947deb80fb509d0ee1ecb
- One-line summary: Build the `order` service in minimal form and wrap its outbound call to a `payment` stub with four Resilience4j defences — circuit breaker, retry, timeout, bulkhead — establishing the defended call as the default unit of inter-service communication for the rest of the curriculum.

---

## 2. Problem & Users

- **Problem statement:** Every subsequent pattern (outbox, sagas, CQRS, idempotency, tracing) assumes outbound calls fail fast and predictably. Without this foundation, each later pattern must debug two things at once: the pattern under study, and the unprotected failure shape of a raw HTTP call. A hung downstream is more dangerous than a dead one — this pattern makes that concrete.
- **Primary user / persona:** Curriculum learner — a developer intentionally working through distributed patterns in order, currently on pattern 2.
- **Jobs-to-be-done:**
  - Understand what each defence does, when it fires, and what happens at the boundary between defences (e.g. retry + circuit breaker interaction).
  - See the full "slow → open → fast-fail → half-open → recover" lifecycle against a real Kubernetes cluster.
  - Walk away with a defensible default configuration they can read in one place and explain per-number.

---

## 3. Scope

**In scope:**
- A new `p2-resilience` Gradle subproject containing a minimal `order` Spring Boot service.
- `POST /orders` endpoint that persists a thin `Order` entity (id, itemId, quantity, status, createdAt) and makes one outbound `POST /payments` call to the WireMock `payment` stub.
- Resilience4j policy for the `payment` dependency: circuit breaker + retry + timeout (TimeLimiter) + semaphore bulkhead.
- All policy configuration declarative in `application.properties`.
- Resilience4j event listeners in a `@Configuration` class emitting structured log events for every call outcome and every circuit breaker state transition.
- Prometheus-scrapeable metrics via Micrometer (Resilience4j auto-exposes via `resilience4j-micrometer`).
- `X-Correlation-ID` header propagation from gateway through order to WireMock, preserved across retries.
- K8s Deployment + Service manifests for the `order` service (NodePort 30002/30082).
- WireMock stub for `POST /payments` — healthy, slow (fixedDelayMilliseconds), error, and recovery variants configured in `canonical-failure.sh`.
- One canonical-failure bash test (`tests/p2-resilience/canonical-failure.sh`) and a `reset.sh`.
- Flyway migration `V001__init.sql` creating the `orders` table in the `p2_resilience` schema.

**Out of scope:**
- Real `payment` service (WireMock only).
- Defending the inbound side of `order` (rate limiting, request-level concurrency caps at the API surface).
- Adaptive or auto-tuned thresholds — all thresholds are static and declared.
- Fallback business logic (e.g. "if payment is down, queue the order") — belongs to p3 outbox.
- Distributed circuit breaker state across multiple `order` pods — each instance maintains its own breaker.
- Response caching at the resilience layer.
- Grafana dashboards (metric exposure via Prometheus scrape is sufficient).
- Saga compensations, outbox writes, idempotency keys, DLQ behaviour.

---

## 4. Decisions Made

| # | Decision | Rationale | Source |
|---|----------|-----------|--------|
| 1 | `POST /orders` → `POST /payments` endpoint shape | Write semantics; realistic for later saga/outbox patterns; retry vs non-retry distinction is meaningful on a POST | Grilling |
| 2 | Persist thin `Order` entity (id, itemId, quantity, status, createdAt) | Sets up p3 outbox cleanly — p3 just adds an outbox column; CLAUDE.md mandates Flyway/JPA | Grilling |
| 3 | `Order.status` lifecycle: `PENDING → ACCEPTED / FAILED` | Maps directly to payment stub outcomes; simple to assert in tests | Grilling |
| 4 | `RestTemplate` for outbound calls | Blocking/linear model easier to read for beginners; Resilience4j decorates cleanly; no reactive programming prerequisite | Grilling |
| 5 | Semaphore bulkhead (not thread-pool) | Fits naturally with RestTemplate in a servlet container; simpler config; excess calls rejected instantly | Grilling |
| 6 | 1-second per-call timeout | Worst case (1s × 3 attempts + 200ms × 2 backoffs = 3.4s) stays under gateway's 5s global limit; makes test assertions fast | Grilling |
| 7 | 2 retry attempts (3 total calls), 200ms fixed backoff | Demonstrates retry mechanic without inflating test runtime | Grilling |
| 8 | Retry only on timeout + connection errors (not 5xx) | Avoids duplicate payment risk; teaches retryable-vs-non-retryable distinction cleanly | Grilling |
| 9 | CB thresholds: window=5, min=5, failure-rate=60%, wait=10s, half-open-probes=2 | Conservative/test-friendly: breaker opens after 3/5 failures, 10s wait is fast enough for a bash test | Grilling |
| 10 | Slow-call threshold: 1s / 80% slow-call rate | Aligns slow-call detection with the per-call timeout | Grilling |
| 11 | Resilience4j event listeners in `@Configuration` for structured logs | Keeps service code clean; all observability wiring in one place | Grilling |
| 12 | Log fields per call: dependency, outcome, attemptCount, latencyMs, correlationId | Matches PD §4 Operability requirement; correlationId from MDC / thread-local | PD + Grilling |
| 13 | NodePort 30002 (app) / 30082 (actuator) | Follows p1-gateway convention (300NN app, 308N actuator); sequential and easy to remember | Grilling |
| 14 | Hardcoded `http://payment:8080` — no K8s service discovery | ClusterIP service `payment` already exists from p1-gateway's `stub-services.yaml`; no RBAC needed | Codebase |
| 15 | One canonical-failure bash test only | PD's definition-of-done is the full CB cycle; a single narrative script exercising all four defences is cleaner than four focused scripts | Grilling |
| 16 | Canonical-failure test asserts `X-Correlation-ID` on all retry attempts via WireMock request log | Catches propagation bugs before p8; explicit assertion is low-cost now, expensive to debug later | Grilling |

---

## 5. Functional Requirements

| Capability | Expected Behaviour |
|---|---|
| Place order | `POST /orders` accepts `{"itemId": "...", "quantity": N}`; persists `Order` with status `PENDING`; calls `POST http://payment:8080/payments` through Resilience4j; updates status to `ACCEPTED` (200) or `FAILED` (non-retryable error / breaker open / bulkhead full); returns appropriate HTTP status + JSON |
| Timeout defence | Any payment call exceeding 1s fires `TimeLimiter`; call counted as failure; returns `503 {"error":"payment_unavailable"}` to caller |
| Retry defence | On timeout or `IOException`, retry up to 2 times with 200ms fixed backoff; stop retrying if circuit breaker is open; business errors and HTTP responses are not retried |
| Circuit breaker | Opens when 3 of last 5 calls fail (60% failure rate) or are slow (>1s, 80% slow-call rate); fast-fails subsequent calls without touching the network; enters half-open after 10s; closes after 2 successful probe calls; re-opens on probe failure |
| Bulkhead | Caps concurrent in-flight payment calls at 10 (semaphore); 11th concurrent call returns `503 {"error":"capacity_exhausted"}` immediately |
| Structured logging | Every call outcome emits one JSON log line: `{dependency, outcome, attemptCount, latencyMs, correlationId}`; every CB state transition emits `{dependency, from, to}` |
| Metrics | Resilience4j Micrometer metrics exposed at `/actuator/prometheus`; includes `resilience4j.circuitbreaker.*`, `resilience4j.retry.*`, `resilience4j.bulkhead.*`, `resilience4j.timelimiter.*` |
| Health endpoint | `/actuator/health` returns readiness signal for K8s probes |
| Correlation-id propagation | `X-Correlation-ID` from inbound request is forwarded on every outbound payment call, including retry attempts |

---

## 6. Non-Functional Requirements

| Concern | Requirement |
|---|---|
| Performance | Per-call timeout 1s; total worst-case latency under gateway's 5s deadline |
| Observability | All four resilience event types (CB, retry, timeout, bulkhead) log structured JSON; Prometheus scrape endpoint active |
| Testability | All thresholds small enough for a bash test to drive the full CB lifecycle in under 60 seconds on a developer laptop |
| Comprehension | Resilience4j configuration declarative in `application.properties`; a non-technical reviewer can read per-dependency thresholds and explain each number |
| Security | No live external HTTP calls; WireMock only |
| Reliability | Single replica; no distributed CB state required |

---

## 7. Data & Domain Model

**Entity: `Order`**

| Field | Type | Notes |
|---|---|---|
| `id` | `BIGINT AUTO_INCREMENT` | Primary key |
| `itemId` | `VARCHAR(50)` | From request body |
| `quantity` | `INT` | From request body |
| `status` | `VARCHAR(20)` | `PENDING` → `ACCEPTED` / `FAILED` |
| `createdAt` | `DATETIME` | Set at insert |

- Schema: `p2_resilience` (per CLAUDE.md naming convention)
- Flyway migration: `V001__init.sql`
- Lifecycle: row is inserted as `PENDING` before the payment call; updated to `ACCEPTED` or `FAILED` after the call resolves (or fails).

---

## 8. Integrations & Dependencies

| System | Direction | Contract |
|---|---|---|
| `p1-gateway` | Upstream → order | Gateway routes `/orders/**` to `lb://order` (ClusterIP); injects `X-Correlation-ID`; applies global 5s response timeout |
| WireMock (`payment` ClusterIP) | Downstream ← order | `POST /payments` stub; metadata `pattern: p2`; returns 200 (healthy), slow response (fixedDelayMilliseconds: 1500), or error response on demand |
| MariaDB (`p2_resilience` schema) | Downstream ← order | Spring Data JPA + Flyway; NodePort 30306 |
| Prometheus | Downstream ← order | Scrapes `/actuator/prometheus` on port 30082 |

---

## 9. Open Questions / Deferred

| Item | Reason Deferred |
|---|---|
| Bulkhead max-concurrent-calls value (10) | Chosen as a sensible default; may need tuning if bash test can't reliably saturate it on a single laptop thread. Revisit in `canonical-failure.sh` authoring. |
| Grafana dashboard for CB state | Explicitly out of scope per PD §5; deferred to p8 |
| Multi-replica CB state behaviour | Explicitly out of scope per PD §5 and §7; acknowledged as a known gap |

---

## 10. Risks & Assumptions

**Risks:**
- **Threshold calibration on slow machines:** The 5-call sliding window and 10s wait duration should be fast enough, but variable Colima VM latency could make results non-deterministic. The canonical-failure test must include `sleep` buffers and assertions with tolerance.
- **Retry amplifying failure:** 2 retries × 1s timeout = up to 3s of blocking before the breaker opens. With 5 minimum calls required, worst case before open = 5 × 3s = 15s. This is within a usable bash test window but should be documented.
- **Correlation-id loss across retries:** Resilience4j's `TimeLimiter` submits calls to a `ScheduledExecutorService`; the MDC context may not propagate. Must use `MDC.getCopyOfContextMap()` and restore it explicitly in the decorated supplier.
- **Scope creep into p3:** Temptation to add a fallback that queues failed payments. Hard rule: failure surfaces to the caller; queueing belongs to p3 outbox.
- **WireMock `fixedDelayMilliseconds` vs timeout race:** The stub delay (1500ms) must reliably exceed the per-call timeout (1000ms) with margin. On a loaded machine, test assertions may need a small tolerance buffer.

**Assumptions:**
- `p1-gateway` is complete and stable; routing, `X-Correlation-ID` propagation, and 5s global timeout are inherited unchanged.
- WireMock `payment` ClusterIP service from `p1-gateway/k8s/stub-services.yaml` is already deployed and routes to the shared WireMock pod.
- MariaDB schema `p2_resilience` does not exist yet and will be created by Flyway on first boot.
- Colima (linux/amd64) build process applies per `scripts/build-and-push.sh` (see project Docker build memory).
- Java 21 (`j21` alias) must be activated before any Gradle command.

---

## 11. Codebase Findings

**Project: p1-gateway**
- Relevant files: `filter/CorrelationIdFilter.java`, `filter/GatewayLoggingFilter.java`, `config/RouteConfig.java`, `k8s/stub-services.yaml`
- `X-Correlation-ID` is the exact header name; injected by `CorrelationIdFilter` at `HIGHEST_PRECEDENCE`; propagated to downstream request and response.
- Global response timeout: `spring.cloud.gateway.server.webflux.httpclient.response-timeout=5s` — p2 per-call timeout must be < 5s total (including retries).
- Structured log JSON fields: `method`, `path`, `downstream`, `status`, `latencyMs`, `correlationId` — p2 should use the same field names for log consistency.
- `stub-services.yaml` defines a ClusterIP service named `payment` (selector: `app: wiremock`) — order service calls `http://payment:8080` directly.
- Resilience4j: **not present** in p1-gateway. No circuit breaker, retry, or bulkhead config exists.

**Project: infra/k8s**
- NodePorts confirmed: WireMock 30080, MariaDB 30306, Kafka 30092, Redis 30379, p1-gateway app 30001, actuator 30081.
- Namespace: `reboot-patterns` (no `kind: Namespace` manifest — assumed to pre-exist).

---

## 12. Handoff Note for /to-spec

**Recommended SPEC scope:**
- One Gradle subproject: `patterns/p2-resilience`
- One Spring Boot service: `order`
- One new K8s Deployment + NodePort Service
- One WireMock stub scenario (POSTed by the bash test, deleted at teardown)
- One Flyway migration
- One bash test (`canonical-failure.sh`) + one `reset.sh`

**Suggested module boundaries:**
```
com.reboot.patterns.p2.resilience
├── OrderApplication.java
├── api/
│   └── OrderController.java          # POST /orders
├── domain/
│   └── Order.java                    # @Entity
├── service/
│   └── OrderService.java             # orchestrates: persist PENDING, call payment, update status
├── infra/
│   ├── OrderRepository.java          # JpaRepository<Order, Long>
│   └── PaymentClient.java            # RestTemplate call, decorated with Resilience4j
└── config/
    ├── ResilienceConfig.java         # CB + Retry + TimeLimiter + Bulkhead beans + event listeners
    └── RestTemplateConfig.java       # RestTemplate @Bean
```

**Hard constraints /to-spec must treat as non-negotiable:**
1. Per-call timeout: 1s (must stay under gateway 5s + retry budget).
2. Retry triggers: timeout + `IOException` only — no HTTP response codes.
3. CB thresholds: window=5, min=5, failure-rate=60%, wait=10s, half-open-probes=2.
4. Bulkhead: semaphore, max-concurrent-calls=10, max-wait=0ms.
5. Log field names must match p1-gateway conventions (`correlationId`, `latencyMs`, `outcome`).
6. No Spring Cloud Kubernetes discovery on order service — hardcode `payment.base-url=http://payment:8080`.
7. No RBAC manifests for order service.
8. NodePorts: 30002 (app), 30082 (actuator).
9. Schema: `p2_resilience`; topic/key prefixes follow CLAUDE.md §5 (no Kafka in p2, but naming must be consistent).
10. Correlation-id propagation must be explicitly tested in `canonical-failure.sh` via WireMock request log assertion.
