# Create Gradle root scaffold

## Spec Reference

ISSUE-1 from `docs/specs/spec-curriculum-setup.md`

## What to build

Bootstrap the Gradle build system so all 8 pattern subprojects can plug in under a single root. Create `settings.gradle` (root project name + 8 subproject includes, commented out until each pattern starts), root `build.gradle` (Java 21 toolchain, Spring Boot + dependency-management plugins applied false, Lombok applied globally), `gradle/libs.versions.toml` (all pinned versions: Boot 3.5.3, Spring Cloud 2025.0.0, Lombok 1.18.38, MapStruct 1.6.3, Resilience4j 2.3.0, Flyway 11.8.2, plus library aliases), and commit the Gradle 8.11.1 wrapper. CLAUDE.md §4 and §11 were already updated during the `/grill-me` session.

## Acceptance Criteria

- [ ] `./gradlew build` exits 0 on a clean checkout with no subprojects yet declared
- [ ] `./gradlew dependencies` shows Spring Boot 3.5.3 and Spring Cloud 2025.0.0 BOM entries resolved without conflict
- [ ] Adding a minimal subproject that declares `implementation libs.spring.boot.starter` resolves the correct version without specifying a version string
- [ ] `gradle/libs.versions.toml` contains all required version aliases (Boot, Cloud, Lombok, MapStruct, Resilience4j, Flyway, Flyway MariaDB dialect, MariaDB JDBC driver)
- [ ] Wrapper scripts (`gradlew`, `gradlew.bat`) are executable and point to Gradle 8.11.1

## Blocked by

None — can start immediately
