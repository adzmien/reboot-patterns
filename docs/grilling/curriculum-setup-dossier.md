# Grilling Context Dossier

## 1. Source PD
- Location: https://www.notion.so/Reboot-Patterns-Distributed-Microservices-Curriculum-5ddb6d88da4e474b85e416783e2bc72b
- One-line summary: Self-directed curriculum to learn 8 distributed microservices patterns by building one focused Spring Boot subproject per pattern in a Gradle monorepo, proven by canonical-failure bash tests against shared K8s infra.

## 2. Problem & Users
- **Problem statement:** The user wants to build distributed-systems intuition through implementation, not reading. The pedagogical bet is medium-tier failure scenarios: every pattern is proven by reproducing the one specific failure it was designed to solve.
- **Primary user / persona:** Solo learner (adzmien) — intentional beginner on these patterns; experienced enough to run K8s, Gradle, and Spring Boot but new to the distributed patterns curriculum.
- **Jobs-to-be-done:** Complete all 8 patterns in sequence, each producing a passing canonical-failure bash test. The curriculum, not any production deployment, is the end goal.

## 3. Scope
- **In scope (this grilling session):** Cross-cutting setup decisions only — K8s infra namespace, Gradle root scaffold, version catalog, naming conventions, image delivery pipeline, and the service-run model that applies to all 8 patterns.
- **Out of scope:** Per-pattern PDs, specs, and implementation details (those go through subsequent `/PD` → `/grill-me` → `/spec` cycles per pattern).

## 4. Decisions Made

| # | Decision | Rationale | Source |
|---|----------|-----------|--------|
| 1 | K8s namespace: `reboot-patterns` | Previous `reboot-infra` namespace deleted; fresh start with correct name matching CLAUDE.md §5 | Grilling |
| 2 | Infra manifests sourced from `com-reboot/reboot-common-k8s` | Existing manifests already have correct NodePorts and working config; adapt by changing namespace only | Codebase |
| 3 | MariaDB init.sql pre-creates all 8 pattern schemas | Flyway manages tables, not schemas; pre-creating with grants means each pattern "just works" without a DBA step | Grilling |
| 4 | MariaDB credentials: `rebootuser` / `abc@123` | Learning project; same credentials as previous projects; zero cognitive overhead | Grilling |
| 5 | Kafka `KAFKA_ADVERTISED_LISTENERS` IP: `100.66.8.44` | Tailscale IP — not the LAN IP (192.168.1.20); this is how the Mac reaches the k3s node | Grilling |
| 6 | Services deployed as K8s Deployments (not `bootRun` processes) | `kubectl scale deployment/<svc> --replicas=0` failure-injection idiom requires K8s Deployments; `bootRun` can't be scaled via kubectl | Grilling |
| 7 | Dockerfiles allowed per subproject (relaxes CLAUDE.md §11) | Option A3: minimal single-stage `eclipse-temurin:21-jre` Dockerfile per pattern service. §11 was written assuming full bootRun; Option A requires K8s deployment. 5-line Dockerfile is honest and repeatable | Grilling |
| 8 | Image delivery: local `registry:2` in `reboot-patterns`, NodePort 30500 | Mac → `docker push 100.66.8.44:30500/service:tag`; k3s pulls from `localhost:30500` via registries.yaml mirror. Faster than scp/import; no SSH needed per deploy. **Port 30500 must be opened by user.** | Grilling |
| 9 | Config format: `application.properties` (overrides CLAUDE.md `application.yml`) | User's explicit preference; applies to all 8 pattern subprojects | Grilling |
| 10 | Spring Boot: 3.5.3 | Latest stable 3.x GA | Grilling |
| 11 | Spring Cloud: 2025.0.0 | Latest stable, confirmed compatible with Boot 3.5.x (references Jackson 2.19.x / Boot 3.5.0 in release notes) | Grilling |
| 12 | Lombok: 1.18.38 | Latest stable | Grilling |
| 13 | MapStruct: 1.6.3 | Latest stable | Grilling |
| 14 | Resilience4j: 2.3.0 | Latest stable (`resilience4j-spring-boot3`) | Grilling |
| 15 | Flyway: 11.8.2 | Latest stable | Grilling |
| 16 | Gradle wrapper: 8.11.1 | Matches `com-reboot` baseline; known working | Codebase |
| 17 | K8s app manifests location: `patterns/p<N>-<pattern>/k8s/` | Keeps each pattern self-contained; bash tests `kubectl apply -f patterns/p<N>-<pattern>/k8s/` | Grilling |
| 18 | WireMock image: `wiremock/wiremock:3.10.0` @ NodePort 30080 | Standard WireMock Docker image | Grilling |
| 19 | Jaeger image: `jaegertracing/all-in-one:1.62.0` @ NodePort 30686 | All-in-one simplest for local learning | Grilling |
| 20 | OTel Collector: `otel/opentelemetry-collector-contrib:0.123.0` (ClusterIP, internal only) | Receives OTLP from services, forwards to Jaeger | Grilling |
| 21 | Prometheus: `prom/prometheus:v3.3.1` @ NodePort 30090 | Standard; scrapes via pod annotations | Grilling |
| 22 | Grafana: `grafana/grafana:11.6.1` @ NodePort 30030 | Standard; Prometheus datasource wired at boot | Grilling |

## 5. Functional Requirements

- **infra/k8s/ — shared infra manifests:** MariaDB (StatefulSet, NodePort 30306), Kafka (StatefulSet, NodePort 30092), Redis (Deployment, NodePort 30379), WireMock (Deployment, NodePort 30080), Jaeger (Deployment, NodePort 30686), OTel Collector (Deployment, ClusterIP), Prometheus (Deployment, NodePort 30090), Grafana (Deployment, NodePort 30030), local container registry (Deployment, NodePort 30500). All in namespace `reboot-patterns`.
- **infra/k8s/ — MariaDB init.sql:** Pre-creates schemas `p1_gateway`, `p2_resilience`, `p3_outbox`, `p4_saga_choreography`, `p5_saga_orchestration`, `p6_cqrs`, `p7_idempotency_dlq`, `p8_observability` and grants all privileges to `rebootuser`.
- **Gradle root scaffold:** `settings.gradle` declares root project + 8 subproject includes. Root `build.gradle` applies Java 21 toolchain, Spring Boot plugin (apply false), dependency-management plugin, shared dependencies (Lombok). `gradle/libs.versions.toml` is the single version source.
- **Per-pattern subproject:** `build.gradle` (pattern-specific deps only), `src/main/java/com/reboot/patterns/p<N>/<pattern>/`, `src/main/resources/application.properties`, `src/main/resources/db/migration/`, `patterns/p<N>-<pattern>/k8s/` (Deployment + Service manifests), minimal `Dockerfile`.
- **k3s registries.yaml:** Must be configured on the k3s node to mirror `localhost:30500` → `100.66.8.44:30500` so pods can pull images pushed from the Mac.
- **reset.sh per pattern:** Drops and recreates the pattern's MariaDB schema, deletes pattern-prefixed Kafka topics, resets WireMock stub mappings tagged with `pattern: p<N>`.

## 6. Non-Functional Requirements

- **Comprehension over elegance:** Explicit `@Bean` definitions, 1–3 line "why this exists" comments on pattern-specific classes. No premature abstractions.
- **Beginner mode:** Simpler implementation wins. No abstractions until a second pattern needs them.
- **Test cap:** ~5 JUnit unit tests per subproject (pure-logic only). Bash scripts are the primary proof surface.
- **No Testcontainers:** Hard ban. K8s + WireMock replaces integration test infra.
- **Frozen stack:** No dependency additions mid-curriculum without explicit discussion.

## 7. Data & Domain Model

- **8 schemas, one per pattern:** `p1_gateway`, `p2_resilience`, `p3_outbox`, `p4_saga_choreography`, `p5_saga_orchestration`, `p6_cqrs`, `p7_idempotency_dlq`, `p8_observability`. Flyway manages tables within each schema.
- **MariaDB:** Single StatefulSet, all schemas in one instance, isolated by schema name. User `rebootuser`, password `abc@123`.
- **Kafka topics:** Prefix `p<N>.<pattern>.<event>` — e.g. `p3.outbox.order-confirmed`. Auto-creation enabled.
- **Redis keys:** Prefix `p<N>:<pattern>:*` — e.g. `p7:idempotency-dlq:idem:`.
- **Domain entities (shared vocabulary):** `order` (place order command), `payment` (authorise via WireMock), `inventory` (reserve/release stock), `shipping` (schedule shipment), `notification` (send email via WireMock). Each pattern implements only the slice it needs.

## 8. Integrations & Dependencies

| Component | Type | Endpoint | Notes |
|-----------|------|----------|-------|
| MariaDB | StatefulSet | `localhost:30306` | `rebootuser`/`abc@123` |
| Kafka | StatefulSet | `localhost:30092` | KRaft mode, single broker, auto-create topics |
| Redis | Deployment | `localhost:30379` | Password `abc@123` |
| WireMock | Deployment | `localhost:30080` | Stubs set up/torn down per test script |
| Jaeger UI | Deployment | `localhost:30686` | OTel Collector → Jaeger OTLP |
| OTel Collector | Deployment | ClusterIP only | Receives OTLP from services via in-cluster address |
| Prometheus | Deployment | `localhost:30090` | Scrapes services via K8s pod annotations |
| Grafana | Deployment | `localhost:30030` | Prometheus datasource pre-configured |
| Local registry | Deployment | `100.66.8.44:30500` | Mac pushes here; k3s pulls via mirror config |
| Spring Cloud Kubernetes | Discovery | K8s API | Gateway discovers services via K8s Service names — works because all services run as K8s Deployments |

## 9. Open Questions / Deferred

- **Per-pattern PDs:** None yet authored. All 8 patterns are "Not started". Subsequent `/PD` → `/grill-me` → `/spec` cycles will cover pattern-specific decisions.
- **Grafana dashboards:** Whether to pre-load dashboards (e.g. JVM metrics, Kafka lag) deferred to Pattern 8 (`p8-observability`) spec.
- **OTel Collector config detail:** OTLP receiver + Jaeger exporter pipeline — deferred to Pattern 8 spec; earlier patterns emit traces but Pattern 8 is where tracing is formally instrumented.
- **Spring Boot Actuator / K8s probes:** Whether to add liveness/readiness probe config to each Deployment deferred to per-pattern specs.

## 10. Risks & Assumptions

| | Item |
|--|------|
| Risk | §11 Dockerfile rule was relaxed mid-session. Future AI skill invocations reading the old CLAUDE.md will still say "no Dockerfiles". **CLAUDE.md §11 must be updated** before any pattern work starts. |
| Risk | `application.yml` is referenced in CLAUDE.md §4 template. **CLAUDE.md §4 must be updated** to `application.properties`. |
| Risk | Port 30500 (local registry) is not yet open on the Tailscale/firewall layer. Image pushes will fail silently until opened. |
| Risk | Spring Cloud 2025.0.0 + Boot 3.5.3 is a very recent combination. There may be undiscovered incompatibilities in Spring Cloud Kubernetes Discovery. Pin and watch. |
| Assumption | k3s `registries.yaml` mirror config is straightforward to set up on Rocky Linux 9.6. If k3s is running as a systemd service, the file lives at `/etc/rancher/k3s/registries.yaml` and requires a service restart. |
| Assumption | Tailscale IP `100.66.8.44` is stable (not DHCP-assigned). If it changes, Kafka `KAFKA_ADVERTISED_LISTENERS` and all NodePort references break. |
| Assumption | `reboot-common-k8s` manifests are the authoritative source for MariaDB, Kafka, and Redis configs. The `reboot-patterns/infra/k8s/` copies should be derived from them, not maintained in parallel. |

## 11. Codebase Findings

- Project: `com-reboot/reboot-common-k8s`
    - `mariadb/`: Secret, ConfigMap (my.cnf + init.sql), StatefulSet (mariadb:11.4, PVC 5Gi), NodePort Service 30306
    - `kafka/`: StatefulSet (apache/kafka:3.9.0, KRaft mode, PVC 2Gi), headless ClusterIP + NodePort Service 30092
    - `redis/`: Secret, Deployment (redis:7.4, appendonly + requirepass), NodePort Service 30379
    - All manifests reference `namespace: reboot-infra` — must be updated to `reboot-patterns`
    - MariaDB init.sql creates UAM schemas — must be replaced with 8 reboot-patterns schemas
    - Kafka `KAFKA_ADVERTISED_LISTENERS` hardcoded to `100.66.8.44:30092` — correct, no change needed

- Project: `com-reboot` (root)
    - Gradle 8.11.1 wrapper confirmed
    - Spring Boot plugin pattern: `id 'org.springframework.boot' version '<x>' apply false` at root
    - `io.spring.dependency-management` version `1.1.6` at root
    - Existing shared dependencies pattern: Lombok declared at root, subproject-specific deps in subproject `build.gradle`

## 12. Handoff Note for /to-spec

**Recommended SPEC scope:** Curriculum infrastructure setup — everything that must exist before Pattern 1 (`p1-gateway`) can be started.

**Suggested deliverables (in order):**
1. Update `CLAUDE.md` §4 (`application.properties`) and §11 (Dockerfiles allowed)
2. `infra/k8s/` manifests — adapt all from `com-reboot/reboot-common-k8s`, add WireMock, Jaeger, OTel Collector, Prometheus, Grafana, local registry
3. `infra/k8s/apply-all.sh` — single script to `kubectl apply -f` everything in order
4. Root Gradle scaffold — `settings.gradle`, `build.gradle`, `gradle/libs.versions.toml`, Gradle wrapper 8.11.1
5. k3s `registries.yaml` setup instructions (one-time, done on the Rocky Linux node)
6. Port 30500 opening reminder (Tailscale/firewall)

**Hard constraints for /to-spec:**
- Namespace must be `reboot-patterns` everywhere
- `application.properties` not `application.yml`
- No Testcontainers
- MariaDB init.sql must pre-create all 8 schemas with grants
- Kafka advertised IP: `100.66.8.44`
- MariaDB credentials: `rebootuser`/`abc@123`
- Gradle 8.11.1, Spring Boot 3.5.3, Spring Cloud 2025.0.0
- All K8s app manifests go in `patterns/p<N>-<pattern>/k8s/` (not in `infra/k8s/`)
