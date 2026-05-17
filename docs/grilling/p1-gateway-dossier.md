# Grilling Context Dossier

## 1. Source PD
- Location: https://www.notion.so/958b788097fc4960887f980480cdd985
- One-line summary: A Spring Cloud Gateway service that is the single entry point for all e-commerce domain services in the Reboot-Patterns curriculum, using Kubernetes-native service discovery.

## 2. Problem & Users
- **Problem statement:** Every later pattern (p2–p8) needs a stable, reliable front door that routes requests to domain services by logical name. Without it, each pattern's bash test would hard-code service locations, making the curriculum brittle and defeating the pedagogical goal of showing real service discovery.
- **Primary users / personas:** A learner (beginner to distributed systems) building each pattern subproject in sequence. The learner is the developer, operator, and test author for each pattern.
- **Jobs-to-be-done:**
  - Prove the shared K8s infrastructure works end-to-end before adding business logic.
  - Establish routing + service-naming conventions inherited by all 8 patterns.
  - Demonstrate fast-fail behaviour at the gateway before p2 deepens it with resilience patterns.

## 3. Scope
**In scope:**
- Single Spring Cloud Gateway service: `p1-gateway`.
- Path-based routes for `order`, `payment`, `inventory`, `shipping`, `notification` (paths match service name: `/order/**`, `/payment/**`, etc.).
- Kubernetes-native service discovery via Spring Cloud Kubernetes Discovery (no prefix stripping; full path forwarded).
- `X-Correlation-ID` propagation — preserved from caller or generated as UUID if absent.
- Bounded 5-second timeout + fast 503 on unreachable/missing downstream.
- 5 stub K8s Services (`order`, `payment`, `inventory`, `shipping`, `notification`) with `selector: app: wiremock` so Spring Cloud Kubernetes Discovery resolves them to WireMock during p1 tests.
- RBAC: namespaced `Role` + `RoleBinding` for the gateway's ServiceAccount in the `reboot-patterns` namespace.
- Health endpoint (`/actuator/health`) and Prometheus-scrapeable metrics (`/actuator/prometheus`) on management port `8081`.
- JSON structured logs (via `logstash-logback-encoder`) — one line per routed request.
- One canonical-failure bash test.

**Out of scope (for now):**
- Retries, circuit breakers, bulkheads (pattern 2).
- Authentication, authorisation, rate limiting.
- Request/response body transformation.
- TLS termination.
- Caching at gateway layer.
- Public-internet exposure.
- Multi-tenant or host-based routing.
- Real downstream services (WireMock stands in for all of them).
- Grafana dashboards (metrics exposure is enough).
- JPA, Flyway, or any MariaDB tables (`p1_gateway` schema exists but stays empty).

## 4. Decisions Made

| # | Decision | Rationale | Source |
|---|----------|-----------|--------|
| 1 | 5 stub K8s Services (`order`, `payment`, `inventory`, `shipping`, `notification`) pointing to WireMock pods (`selector: app: wiremock`) | Real Spring Cloud Kubernetes Discovery works end-to-end; no hacks in gateway config. WireMock differentiates by path. | Grilling |
| 2 | No prefix stripping — forward full path to downstream | Simpler gateway config; WireMock stubs match full paths like `/order/**`. Downstream sees the same path the caller used. | Grilling |
| 3 | Correlation ID header: `X-Correlation-ID` | Self-documenting; does not conflict with B3 tracing headers (used by p8). Inherited by all later patterns. | Grilling |
| 4 | Bounded timeout: 5 seconds | Generous for slow local machines; short enough that the fast-503 test completes quickly. Externalised to `application.properties`. | Grilling |
| 5 | 503 body: `{"status": 503, "error": "Service unavailable", "downstream": "<name>"}` | Machine-readable JSON; bash test can assert both the status and which downstream failed. | Grilling |
| 6 | Gateway NodePort: `30001` (container port `8080`) | Establishes `p<N> → 3000<N>` convention for all 8 patterns. Container port matches WireMock/infra precedent. | Grilling |
| 7 | Management port: `8081` | Separates Prometheus scrape traffic from gateway routing traffic. One property: `management.server.port=8081`. | Grilling |
| 8 | RBAC: namespaced `Role` + `RoleBinding` | Least privilege — gateway only needs to discover services in `reboot-patterns`. `ClusterRole` would be over-privileged. | Grilling |
| 9 | Canonical-failure test: delete the `order` K8s stub Service | Surgical: gateway fails to resolve `order` via discovery → 503. Other services (`payment`) remain discoverable, proving isolation. Restore via `kubectl apply`. | Grilling |
| 10 | Log format: JSON via `logstash-logback-encoder` | Machine-readable; bash tests can use `jq` to assert on log fields. Fields: method, path, downstream, status, latencyMs, correlationId. | Grilling |
| 11 | Route paths match service name exactly: `/order/**`, `/payment/**`, `/inventory/**`, `/shipping/**`, `/notification/**` | Avoids pluralisation edge cases; 1:1 mapping to K8s service names eliminates any mental translation. | Grilling |
| 12 | Correlation ID generated as UUID when absent | Standard Java library, no dependency, universally recognised 36-char format. | Grilling |
| 13 | WireMock happy-path stubs return `{"id": "{{request.pathSegments.[1]}}", "status": "stub-ok"}` | Minimal but assertable; WireMock templating echoes the ID proving pass-through semantics. | Grilling |
| 14 | No JPA or Flyway in p1-gateway | Gateway is a routing layer — no domain entities. `p1_gateway` MariaDB schema pre-exists (created by infra init.sql) but stays empty. | Codebase |
| 15 | `logstash-logback-encoder` must be added to `gradle/libs.versions.toml` | Version catalog is the single source of truth per CLAUDE.md §3. Library is not in catalog yet. | Codebase |
| 16 | `:patterns:p1-gateway` must be uncommented in `settings.gradle` | Line already exists but is commented out. | Codebase |

## 5. Functional Requirements

| Capability | Expected Behaviour |
|------------|--------------------|
| Path-based routing | `GET /order/123` → forwarded to K8s service `order` (full path preserved, no prefix strip) |
| Routing table | `/order/**`, `/payment/**`, `/inventory/**`, `/shipping/**`, `/notification/**` |
| Correlation ID — preserve | If `X-Correlation-ID` header present in inbound request, forward it unchanged to downstream and include in logs |
| Correlation ID — generate | If absent, generate `UUID.randomUUID().toString()`, attach to forwarded request and logs |
| Bounded timeout | Each routed request has a 5-second upper bound; exceeded requests return 503 immediately |
| Downstream unreachable | If K8s service not discoverable (e.g. deleted), return `{"status":503,"error":"Service unavailable","downstream":"<name>"}` within timeout |
| Health endpoint | `GET /actuator/health` returns 200 on management port 8081; Kubernetes liveness/readiness probe target |
| Metrics | `GET /actuator/prometheus` on port 8081 exposes request count, status codes, latency histograms |
| Structured logging | One JSON log line per request: `method`, `path`, `downstream`, `status`, `latencyMs`, `correlationId` |

## 6. Non-Functional Requirements

| Concern | Requirement |
|---------|-------------|
| Performance | No specific SLA — local cluster. Timeout is the only latency bound (5s). |
| Security | No auth/authz at gateway in p1. Correlation ID does not carry sensitive data. |
| Observability | JSON logs scrapeable by log aggregators; Prometheus metrics on port 8081. Dashboards deferred. |
| Resilience | No retries or circuit breakers (p2's job). Only fast-fail via timeout + 503. |
| Portability | All config in `application.properties`. NodePort host externalised. No Spring Cloud Config Server. |
| Comprehensibility | Explicit `@Bean` definitions over auto-config magic; "why this exists" comment on each pattern-specific class (per CLAUDE.md §12). |

## 7. Data & Domain Model

No domain entities. p1-gateway is a pure routing service.

- `p1_gateway` MariaDB schema exists (created by infra init.sql) and is granted to `rebootuser`. It will remain empty — no Flyway migrations needed.
- No Kafka topics.
- No Redis keys.

## 8. Integrations & Dependencies

| System | Role | Contract |
|--------|------|---------|
| Spring Cloud Kubernetes Discovery | Resolves `lb://order` etc. to K8s Endpoints in `reboot-patterns` namespace | Namespaced Role grants `get/list/watch` on `services` and `endpoints` |
| WireMock (K8s service `wiremock`, NodePort 30080) | Serves as all 5 downstream stubs during p1 | Stub K8s Services (`order`, `payment`, etc.) select WireMock pods; stubs identified by metadata `pattern: p1` |
| Prometheus (NodePort 30090) | Scrapes `/actuator/prometheus` on management port 8081 | Prometheus scrape config must be updated to include the gateway pod |
| Local container registry (NodePort 30500) | Hosts the gateway Docker image | Image tag: `localhost:30500/p1-gateway:latest` (internal cluster reference) |
| K8s API server | Discovery client calls `list/watch services` and `list/watch endpoints` in `reboot-patterns` | Requires ServiceAccount + Role + RoleBinding in the gateway's K8s manifest |

## 9. Open Questions / Deferred

| Item | Reason deferred |
|------|----------------|
| Prometheus scrape config update for gateway pod | Out of scope for p1 spec; gateway exposes `/actuator/prometheus` but Prometheus scrape config update is infra concern addressed separately |
| `logstash-logback-encoder` version to pin in catalog | Implementation detail — `/pick-issue` checks Maven Central for the latest stable version at implementation time |
| Exact Logback XML configuration file | Implementation detail — basic JSON stdout appender; no rotation or multiple appenders needed |

## 10. Risks & Assumptions

**Risks:**
- **Discovery RBAC misconfiguration:** If the Role is missing or the ServiceAccount is not set on the Deployment, the gateway starts but logs `AccessDeniedException` from the Kubernetes client. The test will hang or fail with connection-refused rather than the expected 503. Fix: add RBAC verification to the smoke step in the test script.
- **Stub K8s Service selector drift:** If WireMock's pod label changes, the stub Services stop selecting it. The happy-path test fails with 503 even before the failure-injection step. Fix: integration test script verifies WireMock is reachable before running assertions.
- **Timeout calibration:** 5 seconds is a recommendation. A heavily loaded local machine may occasionally breach this during the happy path, producing flaky tests. If this surfaces, the value should be raised and documented, not removed.
- **Convention lock-in:** Route paths, header names, and log field names chosen here will be inherited by all 8 patterns. A change after p2 is implemented is expensive. Chosen conventions are minimal and unambiguous.
- **Correlation-ID propagation gaps:** A `GlobalFilter` that sets the header before routing is correct. If the filter is applied after the routing filter in the chain, the header is missing downstream. Fix: test script asserts the WireMock received request contains `X-Correlation-ID`.

**Assumptions:**
- Shared K8s infrastructure (MariaDB, Kafka, Redis, Jaeger, Prometheus, Grafana, WireMock) is already running and reachable via the documented NodePorts on `100.66.8.44`.
- The frozen stack in CLAUDE.md §3 is non-negotiable. No substitutions.
- WireMock `--global-response-templating` flag (already set in `mocks/deployment/01-deployment.yaml`) enables `{{request.pathSegments.[1]}}` templating in stub responses without per-stub opt-in.
- Bash scripts running outside the cluster use the Tailscale IP `100.66.8.44` to reach NodePorts.
- The gateway runs *inside* the cluster as a K8s Deployment, so it uses cluster-internal DNS for downstream routing (not NodePorts).

## 11. Codebase Findings (scanned)

- **Project:** `reboot-patterns` (root)
  - `infra/k8s/apply-all.sh`: Node IP is `100.66.8.44`; existing NodePorts: 30080 (WireMock), 30090 (Prometheus), 30030 (Grafana), 30306 (MariaDB), 30092 (Kafka), 30379 (Redis), 30686 (Jaeger), 30500 (Registry). Port `30001` is free.
  - `infra/k8s/mariadb/02-configmap.yaml`: `p1_gateway` schema pre-created; `rebootuser` has full grants. No table migrations needed for p1.
  - `mocks/deployment/01-deployment.yaml`: WireMock runs `wiremock/wiremock:3.10.0` with `--global-response-templating`. Pod label: `app: wiremock`.
  - `mocks/deployment/02-service.yaml`: K8s Service named `wiremock`, NodePort `30080`. Stub K8s Services must use the same pod selector (`app: wiremock`).
  - `gradle/libs.versions.toml`: `spring-cloud-starter-gateway` and `spring-cloud-starter-kubernetes-client-all` already in catalog (both managed by Spring Cloud BOM `2025.0.0`). `logstash-logback-encoder` is NOT in the catalog — must be added.
  - `settings.gradle`: Line `//include ':patterns:p1-gateway'` is commented out — must be uncommented.
  - `infra/k8s/prometheus/01-rbac.yaml`: Prometheus ClusterRole precedent shows `get/list/watch` on `services`, `endpoints`, `pods`. Gateway Role should be namespaced and limited to `services` and `endpoints`.
  - `build.gradle`: Root config applies `java` plugin + Java 21 toolchain to all subprojects. Lombok is global. Subprojects opt in to Spring Boot + dependency-management plugins.

## 12. Handoff Note for /to-spec

**Recommended SPEC scope:**
The spec should cover the full p1-gateway subproject from empty directory to passing canonical-failure bash test. That includes: `settings.gradle` edit, `libs.versions.toml` addition, `build.gradle`, `Dockerfile`, K8s manifests (gateway Deployment + Service + RBAC + 5 stub Services), `application.properties`, `GatewayApplication.java`, `CorrelationIdFilter.java`, `RouteConfig.java`, `GatewayLoggingFilter.java`, `GatewayErrorHandler.java`, `logback-spring.xml`, and the two bash test scripts (`reset.sh`, `routing-and-failure.sh`).

**Suggested service / module boundaries:**
- Single Spring Boot application: `p1-gateway` (no sub-modules).
- Package root: `com.reboot.patterns.p1.gateway`.
- K8s manifests: `patterns/p1-gateway/k8s/` (gateway Deployment, Service, ServiceAccount, Role, RoleBinding, + 5 stub Services).
- Tests: `tests/p1-gateway/reset.sh` and `tests/p1-gateway/routing-and-failure.sh`.

**Hard constraints for /to-spec:**
1. `spring-cloud-starter-kubernetes-client-all` is the discovery dependency (not Eureka, not Consul).
2. No JPA, no Flyway, no Kafka, no Redis in p1-gateway's `build.gradle`.
3. Stub K8s Services use `selector: app: wiremock` — they must NOT create a new WireMock deployment.
4. `logstash-logback-encoder` version must be added to `gradle/libs.versions.toml` before being referenced in `build.gradle`.
5. All NodePort references in test scripts use `100.66.8.44` as the node IP (hardcoded in `apply-all.sh`).
6. The canonical-failure test uses `kubectl delete service/order -n reboot-patterns` as the failure idiom (per CLAUDE.md §8: only approved recipes).
7. `reset.sh` for p1: deletes WireMock stubs with `metadata.pattern: p1` via `/__admin/mappings` admin API, then re-applies the 5 stub K8s Services (since the canonical-failure test deletes one).
8. Gateway runs on port `8080` (container); exposed via NodePort `30001`. Management on port `8081` (not exposed via NodePort — Prometheus scrapes via pod IP inside cluster).
9. CLAUDE.md §12 applies: add a 1–3 line "why this exists" comment to every pattern-specific class.
