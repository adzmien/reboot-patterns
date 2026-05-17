# Review Report — issue/11-correlation-id-propagation-and-structured-logging

- **Branch:** `issue/11-correlation-id-propagation-and-structured-logging`
- **Base:** `origin/main`
- **Merge-base:** `77b4ea0`
- **Date:** 2026-05-17
- **Review mode:** Whole branch
- **Grilling depth:** Deep

---

## Commits walked

| SHA | Subject |
|-----|---------|
| `89fb504` | pattern(p1-gateway): add CorrelationIdFilter, GatewayLoggingFilter, and JSON logback config |
| `31f6e8d` | pattern(p1-gateway): expose actuator port 8081 as NodePort 30081 |
| `43c87a4` | pattern(p1-gateway): add changelog for #11 |

---

## Files walked

### Added
- `patterns/p1-gateway/src/main/java/com/reboot/patterns/p1/gateway/filter/CorrelationIdFilter.java`
- `patterns/p1-gateway/src/main/java/com/reboot/patterns/p1/gateway/filter/GatewayLoggingFilter.java`
- `docs/issues/changelogs/11-correlation-id-propagation-and-structured-logging.md`

### Modified
- `patterns/p1-gateway/src/main/resources/logback-spring.xml`
- `patterns/p1-gateway/Dockerfile`
- `patterns/p1-gateway/k8s/03-service.yaml`

---

## Questions, answers, and results

### File 1 — CorrelationIdFilter.java

| # | Question | User's answer | Correct? | Correct answer |
|---|----------|--------------|----------|----------------|
| 1 | Why does `getOrder()` return `HIGHEST_PRECEDENCE`? | B — runs before routing and other filters | ✅ | B |
| 2 | What happens if you skip `remove()` before `add()` on an existing header? | B — downstream receives two headers with different values | ✅ | B |
| 3 | Why can't the lambda capture `correlationId` directly? | C — Reactor requires explicit `final` keyword | ❌ | B — `correlationId` is not effectively final because it was reassigned in the if-block |
| 4 | Why are both exchange attributes AND request header mutation necessary? | B — header travels to downstream services; attribute is an in-process channel for other filters | ✅ | B |
| 5 | Why write the correlation ID onto the HTTP response? | B — lets the original caller record and use it for log searches | ✅ | B |

**Score: 4/5**

### File 2 — GatewayLoggingFilter.java

| # | Question | User's answer | Correct? | Correct answer |
|---|----------|--------------|----------|----------------|
| 1 | Why `GlobalFilter` vs `WebFilter`? | B — `GlobalFilter` gives access to gateway-specific exchange attributes | ✅ | B |
| 2 | What breaks if you log before `chain.filter(exchange)`? | B — status code would be null/0 and latencyMs near 0 | ✅ | B |
| 3 | Why truncate downstream host with `substring(0, indexOf('.'))`? | B — extracts bare service name from Kubernetes FQDN | ✅ | B |
| 4 | Why use `Markers.appendEntries()` vs string interpolation? | B — markers become first-class JSON keys parseable by jq | ✅ | B |
| 5 | What happens at runtime if `CorrelationIdFilter` is removed? | C — Spring refuses to start due to `@Autowired` dependency | ❌ | B — only a compile-time constant reference; attribute absent, null-check logs empty string |

**Score: 4/5**

### File 3 — logback-spring.xml

| # | Question | User's answer | Correct? | Correct answer |
|---|----------|--------------|----------|----------------|
| 1 | What happens to marker fields under the old pattern encoder? | B — silently ignored; `%msg` only renders the message string | ✅ | B |
| 2 | Why suppress `org.springframework.cloud.kubernetes` and `io.fabric8` at WARN? | B — high-volume INFO bootstrap noise floods JSON log output | ✅ | B |
| 3 | What does the `-spring` suffix in `logback-spring.xml` enable? | B — Spring Boot processes the file with the Spring Environment first | ✅ | B |
| 4 | What would logs look like if you deployed the filters but forgot the logback change? | C — no log line at all due to suppressed log level | ❌ | B — plain text line with just "gateway request", all structured fields silently dropped |

**Score: 3/4**

### File 4 — Dockerfile

| # | Question | User's answer | Correct? | Correct answer |
|---|----------|--------------|----------|----------------|
| 1 | What happens when a glob matches multiple files with a single-file destination? | A — Docker refuses to process globs (syntax error) | ❌ | B — Docker treats destination as a directory, fails with "destination must be a directory" |
| 2 | Risk of hardcoding `p1-gateway.jar` without verifying Gradle config? | A — builds successfully but starts with the wrong application | ❌ | B — `COPY` fails at Docker build time with "file not found" |
| 3 | Trade-off of single-stage `eclipse-temurin:21-jre` Dockerfile? | B — fat JAR must be built on the host; no build tooling in the image | ✅ | B |

**Score: 1/3**

### File 5 — k8s/03-service.yaml

| # | Question | User's answer | Correct? | Correct answer |
|---|----------|--------------|----------|----------------|
| 1 | Why a separate actuator port rather than `/actuator` on 8080? | B — reduces security risk; can expose 8080 publicly while keeping 8081 controlled | ✅ | B |
| 2 | What do `port`, `targetPort`, and `nodePort` each control? | A — port=pod listening port, targetPort=Service cluster-internal port (inverted) | ❌ | B — port=Service cluster-internal, targetPort=pod container port, nodePort=external node port |
| 3 | Why does a multi-port Service require `name` on each port? | C — used by kube-proxy for iptables rules | ❌ | B — Kubernetes API requires unique names; names can be referenced by Deployment probes |

**Score: 1/3**

### File 6 — changelogs/11-...md

| # | Question | User's answer | Correct? | Correct answer |
|---|----------|--------------|----------|----------------|
| 1 | Why can't you hit port 8081 on the node IP from your laptop? | B — pod ports are internal; only exposed externally via NodePort | ✅ | B |
| 2 | Correct next step for the deprecated gateway starter follow-up? | B — raise a new GitHub issue; implement via `/pick-issue` workflow | ✅ | B |
| 3 | What goes wrong using route ID instead of `GATEWAY_REQUEST_URL_ATTR` host? | A — route IDs are integers (incorrect) | ❌ | B — route IDs are user-defined strings that may not match K8s service names; URL attr is post-LB-resolution |

**Score: 2/3**

### End-of-branch synthesis

| # | Question | User's answer | Correct? | Correct answer |
|---|----------|--------------|----------|----------------|
| S1 | Trace a no-header request through all three components | B — correct three-link chain | ✅ | B |
| S2 | What breaks if filter order values are swapped? | B — GatewayLoggingFilter runs pre-routing; CorrelationIdFilter runs post-response | ✅ | B |
| S3 | New team member runs `docker build` without `./gradlew bootJar` first | C — builds but crashes with ClassNotFoundException | ❌ | B — fails immediately at `COPY` with "file not found" at build time |
| S4 | In-cluster service calling actuator: which address? | B — Service DNS name with port 8081 | ✅ | B |
| S5 | Reviewer pushback: "use MDC instead of exchange attributes" | C — interchangeable, stylistic choice | ❌ | B — MDC is ThreadLocal; breaks in reactive apps where requests hop threads |
| S6 | Does the branch comply with CLAUDE.md §6 one-logical-change-per-commit rule? | B — yes; filters+logback are one logical unit | ✅ | B |

**Synthesis score: 4/6**

---

## Weak areas and suggested re-reads

### Weak areas

1. **Java effectively-final rule** (File 1 Q3, recurring theme)
   Any reassignment of a local variable — even conditional — removes its effectively-final status. Lambda capture requires effectively-final. The `final String resolvedId = correlationId` copy is the canonical fix.

2. **Docker `COPY` is build-time, not runtime** (File 4 Q1, Q2, Synthesis S3 — three misses)
   `COPY` evaluates at `docker build` time against the local filesystem. Missing file = immediate build failure. No JAR is created, no container is started. Commit to this model: "Dockerfile instructions = recipe executed at build time against what's on disk now."

3. **Kubernetes port field direction** (File 5 Q2)
   Traffic path: `laptop → nodePort (node NIC) → Service port → pod targetPort`. `port` is what in-cluster callers dial on the Service; `targetPort` is what the pod container actually listens on.

4. **MDC vs exchange attributes in reactive** (Synthesis S5)
   MDC uses `ThreadLocal` — one value per thread. Reactor hops threads mid-request. Exchange attributes are scoped to the exchange object and travel across thread switches. This distinction will recur in every reactive filter you write.

### Suggested re-reads
- [GatewayLoggingFilter.java:36-55](../patterns/p1-gateway/src/main/java/com/reboot/patterns/p1/gateway/filter/GatewayLoggingFilter.java#L36-L55) — the `.then(Mono.fromRunnable(...))` post-response pattern.
- Spring WebFlux `ServerWebExchange` Javadoc — `getAttributes()` vs MDC.
- Kubernetes Service docs — draw the three-hop traffic path: `nodePort → port → targetPort`.

---

## Risks for pre-merge follow-up

1. **No log injection sanitization** — a caller-supplied `X-Correlation-ID` with newlines or control characters could corrupt JSON log output. Acceptable for learning; flag for production hardening.
2. **`System.currentTimeMillis()` for latency measurement** — wall-clock time; subject to NTP adjustments. Prefer `System.nanoTime()` for elapsed-time accuracy in production.
3. **Deprecated gateway starter** — `spring-cloud-starter-gateway` should be migrated to `spring-cloud-starter-gateway-server-webflux`. Needs a new GitHub issue.
4. **Cross-platform build process** — `linux/amd64` images on macOS ARM64 require `docker buildx` inside Colima VM. Process should be codified in a Makefile or helper script.
5. **AC6 spec correction** — the issue spec cites port 8081 (internal pod port) as the external address; correct external address is NodePort 30081. Spec should be updated.
