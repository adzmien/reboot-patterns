# reboot-patterns

A self-directed curriculum to learn 8 distributed microservices patterns by building one focused Spring Boot subproject per pattern.

**Curriculum, rationale, and lifecycle live in the main PD in Notion: [Reboot-Patterns — Distributed Microservices Curriculum](https://www.notion.so/5ddb6d88da4e474b85e416783e2bc72b).** This `README.md` is operational only.

## 1. Prerequisites

- **Java 21** (e.g. `sdk install java 21-tem`)
- **Gradle wrapper** — committed in repo, no global install needed
- **kubectl** with a working context pointing at the cluster that hosts shared infra
- **A running Kubernetes cluster** (Docker Desktop, kind, k3d, k3s, or remote — all fine)
- **kcat** (preferred) or `kafka-console-consumer.sh` / `kafka-console-producer.sh`
- **mysql** client (`mysql-client` package)
- **jq**, **curl** (used heavily in bash tests)

## 2. One-time infra setup

Deploy the shared infra and mocks into the `reboot-patterns` namespace:

~~~bash
kubectl create namespace reboot-patterns

kubectl apply -f infra/k8s/ -n reboot-patterns
kubectl apply -f mocks/deployment/ -n reboot-patterns

# Verify everything is Ready
kubectl get pods -n reboot-patterns -w
~~~

Confirm NodePort reachability (replace `<node>` with your cluster node IP, often `localhost` for Docker Desktop / kind):

~~~bash
curl http://<node>:30080/__admin/health    # WireMock
curl http://<node>:30686/                  # Jaeger UI
curl http://<node>:30030/                  # Grafana
~~~

You set this up **once**. Pattern subprojects only need it running.

## 3. NodePort map (fixed)

| Component | NodePort | Connection from app |
|---|---|---|
| MariaDB | 30306 | `jdbc:mariadb://<node>:30306/p<N>_<pattern>` |
| Kafka | 30092 | `<node>:30092` |
| Redis | 30379 | `redis://<node>:30379` |
| Jaeger UI | 30686 | browser |
| Prometheus | 30090 | browser / scrape |
| Grafana | 30030 | browser |
| WireMock admin | 30080 | `http://<node>:30080` |

These are referenced verbatim in every `application.yml`. Do not re-allocate.

## 4. Run a pattern locally

~~~bash
cd patterns/p<N>-<pattern>
./gradlew bootRun
~~~

Each subproject's own `README.md` lists which other pattern services need to be running alongside it (most patterns run a small handful of services in parallel terminals).

## 5. Run tests for a pattern

~~~bash
# JUnit unit tests (pure logic only — fast)
cd patterns/p<N>-<pattern>
./gradlew test

# Bash scenario tests (run from repo root)
./tests/p<N>-<pattern>/<scenario>.sh
~~~

Every bash script self-narrates its steps and calls `reset.sh` first. The **canonical-failure** script per pattern is the definition-of-done gate.

## 6. Reset the world

Wipes all per-pattern data without redeploying infra:

~~~bash
# Per pattern
./tests/p<N>-<pattern>/reset.sh

# All patterns at once
for d in tests/p*/; do "$d/reset.sh"; done
~~~

## 7. AI workflow quick reference

For each pattern, run this loop. Detailed lifecycle in the main PD.

| # | Skill / action | Where |
|---|---|---|
| 1 | `/teach-me` | Notion |
| 2 | `/PD` | Notion (sub-page of main PD) |
| 3 | `/grill-me` (codebase) | Claude Code |
| 4 | `/spec` | Claude Code → `docs/specs/` |
| 5 | `/to-issues` | Claude Code → GitHub |
| 6 | `/pick-issue` (implement + commit) | Claude Code |
| 7 | `/generate-tests` | Claude Code → `tests/` |
| 8 | Run bash tests | terminal |
| 9 | `/reflect` | Claude Code |
| 10 | `/doc` | Claude Code |
| 11 | Loop 6–10 until canonical-failure test passes | — |
| 12 | Next pattern | — |

Conventions for AI generation live in [`CLAUDE.md`](./CLAUDE.md).

## 8. Repo layout

~~~
reboot-patterns/
├── CLAUDE.md
├── README.md
├── settings.gradle, build.gradle
├── gradle/libs.versions.toml
├── infra/k8s/                    # shared infra manifests
├── mocks/                        # WireMock deployment + reusable stubs
├── docs/specs/                   # output of /spec
├── patterns/p<N>-<pattern>/      # 8 Spring Boot subprojects
└── tests/p<N>-<pattern>/         # bash scenarios + reset.sh
~~~

## 9. Pattern index

| # | Pattern | Subproject | Status | Per-subproject README |
|---|---|---|---|---|
| 1 | API Gateway + Service Discovery | `patterns/p1-gateway` | Not started | [link](./patterns/p1-gateway/README.md) |
| 2 | Resilience | `patterns/p2-resilience` | Not started | [link](./patterns/p2-resilience/README.md) |
| 3 | Transactional Outbox | `patterns/p3-outbox` | Not started | [link](./patterns/p3-outbox/README.md) |
| 4 | Saga (Choreography) | `patterns/p4-saga-choreography` | Not started | [link](./patterns/p4-saga-choreography/README.md) |
| 5 | Saga (Orchestration) | `patterns/p5-saga-orchestration` | Not started | [link](./patterns/p5-saga-orchestration/README.md) |
| 6 | CQRS + Materialized View | `patterns/p6-cqrs` | Not started | [link](./patterns/p6-cqrs/README.md) |
| 7 | Idempotent Consumer + DLQ | `patterns/p7-idempotency-dlq` | Not started | [link](./patterns/p7-idempotency-dlq/README.md) |
| 8 | Distributed Tracing + Correlation | `patterns/p8-observability` | Not started | [link](./patterns/p8-observability/README.md) |

`/doc` updates the Status column as patterns complete.