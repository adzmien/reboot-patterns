# p2-resilience Gradle Subproject Scaffold

## Spec Reference
ISSUE-1 from `docs/specs/spec-p2-resilience.md`

## What to build

Create the `patterns/p2-resilience` Gradle subproject with all build boilerplate needed for the `order` service to compile and boot. This is the foundation that every subsequent p2 issue depends on.

Deliverables:
- `patterns/p2-resilience/build.gradle` — references `libs.*` from the version catalog; includes `spring-boot-starter-web`, `spring-boot-starter-data-jpa`, `spring-boot-starter-actuator`, `resilience4j-spring-boot3`, `micrometer-registry-prometheus`, `flyway-core`, `flyway-mysql`, `mariadb-java-client`, `logstash-logback-encoder`
- `patterns/p2-resilience/Dockerfile` — single-stage `eclipse-temurin:21-jre` image
- `settings.gradle` updated to include `:patterns:p2-resilience`
- `OrderApplication.java` at `com.reboot.patterns.p2.resilience`
- `application.properties` skeleton: `spring.application.name=p2-order`, server port 8080, actuator port 8081, MariaDB connection to `localhost:30306` schema `p2_resilience`, Flyway enabled
- `logback-spring.xml` copied/adapted from p1-gateway (LogstashEncoder, single-line JSON to stdout)

## Acceptance Criteria

- [ ] `j21 && ./gradlew :patterns:p2-resilience:build` compiles without errors
- [ ] `java -jar` boots and `/actuator/health` returns `{"status":"UP"}` when MariaDB NodePort 30306 is reachable
- [ ] Application logs structured JSON (LogstashEncoder) to stdout
- [ ] `application.name` in logs shows `p2-order`

## Blocked by

None — can start immediately
