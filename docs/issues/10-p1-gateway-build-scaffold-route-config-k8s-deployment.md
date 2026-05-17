# p1-gateway Build Scaffold + Route Config + K8s Deployment

## Spec Reference

ISSUE-1 + ISSUE-2 from `docs/specs/spec-p1-gateway.md`

## What to build

Bootstrap the `:patterns:p1-gateway` Gradle subproject and deliver a running gateway pod in `reboot-patterns` that routes requests to the correct WireMock stub — verifiable end-to-end with `curl`.

**Build scaffold (Slice 0 tasks folded in):**
- Add `logstash-logback-encoder = { module = "net.logstash.logback:logstash-logback-encoder", version = "8.0" }` to `gradle/libs.versions.toml` under `[libraries]`
- Uncomment `include ':patterns:p1-gateway'` in `settings.gradle`
- Create `patterns/p1-gateway/build.gradle` with Spring Boot + Spring Cloud BOM imports and all required dependencies (`spring-cloud-starter-gateway`, `spring-cloud-starter-kubernetes-client-all`, `spring-boot-starter-actuator`, `micrometer-registry-prometheus`, `logstash-logback-encoder`, `spring-boot-starter-test`)
- Create `GatewayApplication.java` (entry point with `@SpringBootApplication`)
- Create `application.properties` with all required properties (ports, namespace, timeout, actuator exposure, logback config path)
- Create `Dockerfile` (single-stage `eclipse-temurin:21-jre`)

**Route configuration:**
- Create `RouteConfig.java` — `RouteLocator` `@Bean` with 5 path-based routes (`/order/**`, `/payment/**`, `/inventory/**`, `/shipping/**`, `/notification/**`) using `lb://` URIs; global 5-second HTTP client timeout via `spring.cloud.gateway.httpclient.response-timeout=5s`

**Kubernetes manifests (`patterns/p1-gateway/k8s/`):**
- `01-rbac.yaml` — `ServiceAccount`, namespaced `Role` (get/list/watch services + endpoints in `reboot-patterns`), `RoleBinding`
- `02-deployment.yaml` — `Deployment` with `image: localhost:30500/p1-gateway:latest`, `serviceAccountName`, ports 8080 (routing) + 8081 (actuator)
- `03-service.yaml` — `Service` NodePort 30001 → 8080
- `stub-services.yaml` — 5 ClusterIP `Service` objects (names: `order`, `payment`, `inventory`, `shipping`, `notification`; `selector: app: wiremock`; port 8080)

**Delivery:** build JAR, build and push Docker image to `100.66.8.44:30500`, apply all K8s manifests, verify routing via `curl`.

`application.properties` required content:
```properties
spring.application.name=p1-gateway
server.port=8080

spring.cloud.kubernetes.namespace=reboot-patterns
spring.cloud.kubernetes.discovery.all-namespaces=false

spring.cloud.gateway.httpclient.response-timeout=5s

management.server.port=8081
management.endpoints.web.exposure.include=health,prometheus
management.metrics.export.prometheus.enabled=true

logging.config=classpath:logback-spring.xml
```

## Acceptance Criteria

- [ ] `./gradlew :patterns:p1-gateway:bootJar` exits 0 and produces a non-empty JAR in `patterns/p1-gateway/build/libs/`
- [ ] `docker build -t 100.66.8.44:30500/p1-gateway:latest patterns/p1-gateway/` and `docker push` exit 0
- [ ] `kubectl get pods -n reboot-patterns` shows `p1-gateway` pod in `Running` state
- [ ] `kubectl get services -n reboot-patterns` shows `order`, `payment`, `inventory`, `shipping`, `notification` services with `selector: app=wiremock`
- [ ] `GET http://100.66.8.44:30001/order/123` (with WireMock stub pre-loaded) returns HTTP 200 with body containing `"status":"stub-ok"`
- [ ] `GET http://100.66.8.44:30001/payment/456`, `/inventory/789`, `/shipping/111`, `/notification/222` each return HTTP 200
- [ ] After `kubectl rollout restart deployment/wiremock -n reboot-patterns`, the next `GET /order/123` still returns HTTP 200 without restarting the gateway (self-healing discovery)
- [ ] `GET http://100.66.8.44:30001/unknown/path` returns HTTP 404 (no matching route)
- [ ] `kubectl auth can-i list services --as system:serviceaccount:reboot-patterns:p1-gateway -n reboot-patterns` returns `yes`

## Blocked by

None — can start immediately
