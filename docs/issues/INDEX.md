# Issues Index

| ID  | Title                                                        | Type | Status | Spec    | Blocked by                          | File                                                              |
| --- | ------------------------------------------------------------ | ---- | ------ | ------- | ----------------------------------- | ----------------------------------------------------------------- |
| #1  | Create Gradle root scaffold                                  | AFK  | done        | ISSUE-1 | —                              | `1-create-gradle-root-scaffold.md`                                |
| #2  | Adapt and deploy MariaDB to reboot-patterns                  | AFK  | done | ISSUE-2 | #1                                    | `2-adapt-and-deploy-mariadb-to-reboot-patterns.md`                |
| #3  | Adapt and deploy Kafka to reboot-patterns                    | AFK  | done        | ISSUE-3 | —                              | `3-adapt-and-deploy-kafka-to-reboot-patterns.md`                  |
| #4  | Adapt and deploy Redis to reboot-patterns                    | AFK  | done        | ISSUE-4 | —                              | `4-adapt-and-deploy-redis-to-reboot-patterns.md`                  |
| #5  | Deploy WireMock and create mocks directory structure         | AFK  | done        | ISSUE-5 | —                              | `5-deploy-wiremock-and-create-mocks-directory-structure.md`       |
| #6  | Deploy Jaeger and OTel Collector                             | AFK  | done        | ISSUE-6 | —                                   | `6-deploy-jaeger-and-otel-collector.md`                           |
| #7  | Deploy Prometheus and Grafana                                | AFK  | done | ISSUE-7 | —                                   | `7-deploy-prometheus-and-grafana.md`                              |
| #8  | Deploy local registry and configure k3s mirror               | AFK  | done        | ISSUE-8 | —                              | `8-deploy-local-registry-and-configure-k3s-mirror.md`            |
| #9  | Write infra/k8s/apply-all.sh with smoke checks               | AFK  | done        | ISSUE-9 | #2, #3, #4, #5, #6, #7, #8    | `9-write-infra-k8s-apply-all-sh-with-smoke-checks.md`            |
| #10 | p1-gateway Build Scaffold + Route Config + K8s Deployment    | AFK  | done   | ISSUE-1 + ISSUE-2 | —           | `10-p1-gateway-build-scaffold-route-config-k8s-deployment.md`    |
| #11 | Correlation ID Propagation + Structured Logging              | AFK  | done        | ISSUE-3 | #10                       | `11-correlation-id-propagation-and-structured-logging.md`        |
| #12 | Fast-Fail Error Handling + Canonical-Failure Test Infra      | AFK  | done   | ISSUE-4 | #11                            | `12-fast-fail-error-handling-and-canonical-failure-test-infrastructure.md` |
| #13 | Codify Cross-Platform amd64 Docker Build Process             | AFK  | done        | —       | #11                       | `13-codify-cross-platform-amd64-docker-build-process.md`                  |
| #14 | p2-resilience Gradle subproject scaffold                     | AFK  | open   | ISSUE-1 | —                          | `14-p2-resilience-gradle-subproject-scaffold.md`                  |
| #15 | Order entity + Flyway V001__init.sql                         | AFK  | open   | ISSUE-2 | #14                        | `15-order-entity-and-flyway-migration.md`                         |
| #16 | PaymentClient with plain RestTemplate                        | AFK  | open   | ISSUE-3 | #14                        | `16-payment-client-plain-rest-template.md`                        |
| #17 | OrderController + OrderService                               | AFK  | open   | ISSUE-4 | #15, #16                   | `17-order-controller-and-order-service.md`                        |
| #18 | K8s manifests + deployment verification                      | AFK  | open   | ISSUE-5 | #17                        | `18-k8s-manifests-and-deployment-verification.md`                 |
| #19 | ResilienceConfig — bean declarations + thresholds            | AFK  | open   | ISSUE-6 | #14                        | `19-resilience-config-bean-declarations-and-thresholds.md`        |
| #20 | Decorate PaymentClient with all four defences                | AFK  | open   | ISSUE-7 | #18, #19                   | `20-decorate-payment-client-with-all-four-defences.md`            |
| #21 | Event listeners + structured logging                         | AFK  | open   | ISSUE-8 | #20                        | `21-event-listeners-and-structured-logging.md`                    |
| #22 | reset.sh for p2-resilience                                   | AFK  | open   | ISSUE-9 | #18                        | `22-reset-sh.md`                                                  |
| #23 | canonical-failure.sh — full circuit breaker lifecycle        | AFK  | open   | ISSUE-10| #21, #22                   | `23-canonical-failure-sh-full-circuit-breaker-lifecycle.md`       |
