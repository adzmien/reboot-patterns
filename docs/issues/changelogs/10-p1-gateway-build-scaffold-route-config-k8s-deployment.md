# Changelog — #10 p1-gateway Build Scaffold + Route Config + K8s Deployment

- **Branch:** `issue/10-p1-gateway-build-scaffold-route-config-k8s-deployment`
- **Date:** 2026-05-17 (UTC+8, Asia/Kuala_Lumpur)
- **Iterations used:** 1 (scaffold committed before this session) + 1 fix iteration = 2
- **Status:** complete

---

## Proposed squash commit message

```text
pattern(p1-gateway): scaffold build, route config, and k8s deployment

Bootstrap the :patterns:p1-gateway Gradle subproject with Spring Cloud Gateway
(reactive/Netty) and Kubernetes-native service discovery. Five path-based routes
(/order/**, /payment/**, /inventory/**, /shipping/**, /notification/**) resolve
upstream services via lb:// using ClusterIP mode — required because pod-to-pod
direct routing is unreliable in this K3s/Flannel setup. RBAC grants the gateway
ServiceAccount get/list/watch on services, endpoints, and pods. Five stub ClusterIP
Services select the shared WireMock pod so all routes respond with HTTP 200.

Acceptance criteria:
- [x] `./gradlew :patterns:p1-gateway:bootJar` exits 0 and produces a non-empty JAR
- [x] `docker buildx build --platform linux/amd64` and push exit 0
- [x] `kubectl get pods -n reboot-patterns` shows `p1-gateway` pod in Running state
- [x] `kubectl get services -n reboot-patterns` shows order, payment, inventory, shipping, notification with selector app=wiremock
- [x] `GET http://100.66.8.44:30001/order/123` returns HTTP 200 with body containing "status":"stub-ok"
- [x] `GET http://100.66.8.44:30001/payment/456`, `/inventory/789`, `/shipping/111`, `/notification/222` each return HTTP 200
- [x] After `kubectl rollout restart deployment/wiremock`, next `GET /order/123` returns HTTP 200 without restarting gateway
- [x] `GET http://100.66.8.44:30001/unknown/path` returns HTTP 404
- [x] `kubectl auth can-i list services --as system:serviceaccount:reboot-patterns:p1-gateway -n reboot-patterns` returns yes

Closes #10.
```

---

## Summary of changes

- Bootstrapped `:patterns:p1-gateway` Gradle subproject with Spring Boot 3.5.3 + Spring Cloud 2025.0.0 BOM, Spring Cloud Gateway (Netty/reactive), `spring-cloud-starter-kubernetes-client-all`, Actuator, Micrometer Prometheus, and `logstash-logback-encoder`.
- Created `RouteConfig.java` with 5 explicit path-based routes using `lb://` URIs and `spring.cloud.kubernetes.loadbalancer.mode=SERVICE` so discovery resolves via ClusterIP (pod-to-pod direct IPs are unreliable in this K3s setup).
- Created K8s manifests: `01-rbac.yaml` (ServiceAccount + Role with get/list/watch on services, endpoints, pods + RoleBinding), `02-deployment.yaml` (port 8080 routing + 8081 actuator with probes), `03-service.yaml` (NodePort 30001), and `stub-services.yaml` (5 ClusterIP Services selecting WireMock).
- Fixed Dockerfile COPY glob (`p1-gateway-*.jar` → `p1-gateway*.jar`) — Gradle produces an unversioned jar name without the `-` separator.
- Cross-compilation: image built for `linux/amd64` via `docker buildx` inside the Colima VM, pushed to the cluster-local registry at `100.66.8.44:30500`.

---

## Acceptance criteria status

| # | Criterion | Status | Note |
|---|-----------|--------|------|
| AC1 | `bootJar` exits 0 with non-empty JAR | ✅ | 70 MB JAR in `build/libs/` |
| AC2 | `docker build` + `docker push` exit 0 | ✅ | Built amd64 via `buildx` in Colima VM |
| AC3 | `p1-gateway` pod in Running state | ✅ | 1/1 Running |
| AC4 | 5 stub Services with `selector: app=wiremock` | ✅ | order, payment, inventory, shipping, notification |
| AC5 | `GET /order/123` → HTTP 200 with `"status":"stub-ok"` | ✅ | Verified via curl |
| AC6 | All 5 routes → HTTP 200 | ✅ | All verified |
| AC7 | Self-healing after wiremock restart | ✅ | Routes return 200 without gateway restart |
| AC8 | `GET /unknown/path` → HTTP 404 | ✅ | Verified |
| AC9 | `kubectl auth can-i list services` → yes | ✅ | Verified |

---

## Files changed

### Added
- `patterns/p1-gateway/Dockerfile`
- `patterns/p1-gateway/build.gradle`
- `patterns/p1-gateway/k8s/01-rbac.yaml`
- `patterns/p1-gateway/k8s/02-deployment.yaml`
- `patterns/p1-gateway/k8s/03-service.yaml`
- `patterns/p1-gateway/k8s/stub-services.yaml`
- `patterns/p1-gateway/src/main/java/com/reboot/patterns/p1/gateway/GatewayApplication.java`
- `patterns/p1-gateway/src/main/java/com/reboot/patterns/p1/gateway/config/RouteConfig.java`
- `patterns/p1-gateway/src/main/resources/application.properties`
- `patterns/p1-gateway/src/main/resources/logback-spring.xml`

### Modified
- `gradle/libs.versions.toml` — `logstash-logback-encoder` entry (already present; `settings.gradle` `:patterns:p1-gateway` include already uncommented)
- `settings.gradle` — `:patterns:p1-gateway` include uncommented

---

## Commits on branch

```
5546baf pattern(p1-gateway): fix Dockerfile glob, RBAC pods permission, and properties
f92da50 pattern(p1-gateway): scaffold build, route config, and k8s deployment
```

---

## Verification

### `./gradlew :patterns:p1-gateway:bootJar`
Green. Output: `BUILD SUCCESSFUL in 1s` — `p1-gateway.jar` (70 MB) in `patterns/p1-gateway/build/libs/`.

### Cluster curl results

```
order/123        → HTTP 200: {"id":"123","service":"order","status":"stub-ok"}
payment/456      → HTTP 200: {"id":"123","service":"payment","status":"stub-ok"}
inventory/789    → HTTP 200: {"id":"123","service":"inventory","status":"stub-ok"}
shipping/111     → HTTP 200: {"id":"123","service":"shipping","status":"stub-ok"}
notification/222 → HTTP 200: {"id":"123","service":"notification","status":"stub-ok"}
unknown/path     → HTTP 404
```

Self-healing: after `kubectl rollout restart deployment/wiremock`, re-loaded stubs, and `GET /order/123` returned HTTP 200 without restarting the gateway.

---

## Outstanding follow-ups

1. **Cross-platform build process:** Building for `linux/amd64` requires `docker buildx` inside the Colima VM (host Docker is ARM64 only). This is manual. Issue #9's `apply-all.sh` should be extended with a build step or a Makefile target.
2. **Colima insecure registry:** The `100.66.8.44:30500` insecure registry entry was added to Colima's Docker daemon manually (`colima ssh` + `systemctl reload docker`). This should be codified in `colima.yaml` or provisioning docs.
3. **Deprecated starter warning:** `spring-cloud-starter-gateway` is deprecated in favour of `spring-cloud-starter-gateway-server-webflux`. Migration is low-risk but should be tracked as a follow-up (not in scope for issue #10).
4. **WireMock stub persistence:** Stubs are lost on wiremock pod restart. The self-healing AC passed because stubs were re-loaded manually before testing. Issue #12's canonical-failure test should handle stub re-loading in `reset.sh`.
