# Changelog — #1 Create Gradle root scaffold

- **Branch:** `issue/1-create-gradle-root-scaffold`
- **Date:** 2026-05-10 (Asia/Kuala_Lumpur, UTC+8)
- **Iterations used:** 1 (build green on first attempt; test-module verification took one extra fix for version catalog accessor syntax)
- **Status:** Complete — all acceptance criteria met

---

## Proposed squash commit message

```text
feat(#1): create Gradle root scaffold

Bootstrap the Gradle 8.11.1 build system with settings.gradle (root
project name + 8 commented-out pattern subproject includes), root
build.gradle (Java 21 toolchain, Spring Boot 3.5.3 and
io.spring.dependency-management 1.1.7 applied false, Lombok 1.18.38
globally applied to all subprojects), and gradle/libs.versions.toml
(all version pins and library aliases for the full 8-pattern stack).

Verified: ./gradlew build exits 0 with no subprojects declared; a
temporary test-module confirmed libs.spring.boot.starter resolves
spring-boot-starter:3.5.3 and spring-cloud-dependencies:2025.0.0
without version strings in subproject build files.

Acceptance criteria:
- [x] ./gradlew build exits 0 on a clean checkout with no subprojects declared
- [x] ./gradlew dependencies shows Spring Boot 3.5.3 and Spring Cloud 2025.0.0 BOM entries resolved without conflict
- [x] Adding a minimal subproject that declares implementation libs.spring.boot.starter resolves the correct version without specifying a version string
- [x] gradle/libs.versions.toml contains all required version aliases (Boot, Cloud, Lombok, MapStruct, Resilience4j, Flyway, Flyway MariaDB dialect, MariaDB JDBC driver)
- [x] Wrapper scripts (gradlew, gradlew.bat) are executable and point to Gradle 8.11.1

Closes #1.
```

---

## Summary of changes

- Created `settings.gradle` with root project name `reboot-patterns` and all 8 pattern subproject includes commented out, ready to uncomment per-pattern.
- Created `gradle/libs.versions.toml` with all version pins (Spring Boot 3.5.3, Spring Cloud 2025.0.0, Lombok 1.18.38, MapStruct 1.6.3, Resilience4j 2.3.0, Flyway 11.8.2, MariaDB 3.5.3) and library aliases for all dependencies the 8 patterns will need.
- Created root `build.gradle` applying Spring Boot and dependency-management plugins with `apply false`, and a `subprojects {}` block that pins Java 21 toolchain, sets `mavenCentral()`, and wires Lombok globally.
- Generated the Gradle 8.11.1 wrapper (`gradlew`, `gradlew.bat`, `gradle/wrapper/`) using the system Gradle 9.2.1 installation.
- Verified version catalog accessor syntax: hyphen-separated aliases in `[versions]` create nested Groovy accessors (e.g. `spring-boot` → `libs.versions.spring.boot.get()`), not camelCase — documented for future subproject authors.

---

## Acceptance criteria status

| # | Criterion | Status |
|---|-----------|--------|
| AC1 | `./gradlew build` exits 0 with no subprojects declared | ✅ Green — `BUILD SUCCESSFUL` confirmed |
| AC2 | `./gradlew dependencies` shows Spring Boot 3.5.3 and Spring Cloud 2025.0.0 BOM entries | ✅ Verified via temporary `test-module` with explicit BOM imports |
| AC3 | `implementation libs.spring.boot.starter` resolves `3.5.3` without a version string | ✅ Confirmed — `spring-boot-starter:3.5.3` in `compileClasspath` of test-module |
| AC4 | `gradle/libs.versions.toml` contains all required version aliases | ✅ All aliases present: Boot, Cloud, Lombok, MapStruct, Resilience4j, Flyway, flyway-mysql, MariaDB JDBC |
| AC5 | `gradlew` executable, wrapper points to Gradle 8.11.1 | ✅ `gradlew` has `rwxr-xr-x`; `gradle-wrapper.properties` contains `gradle-8.11.1-bin.zip` |

---

## Files changed

**Added (7):**
- `build.gradle`
- `gradle/libs.versions.toml`
- `gradle/wrapper/gradle-wrapper.jar`
- `gradle/wrapper/gradle-wrapper.properties`
- `gradlew`
- `gradlew.bat`
- `settings.gradle`

**Modified (0):** none

**Deleted (0):** none

---

## Commits on branch

```
b399283 feat(#1): create Gradle root scaffold
```

---

## Verification

**`./gradlew build`:** `BUILD SUCCESSFUL in 258ms` — 1 actionable task executed.

**`bootRun`:** N/A — this is a build scaffold, not a Spring Boot application.

**AC2/AC3 test-module run:** A temporary `test-module/` subproject was created with `org.springframework.boot` and `io.spring.dependency-management` applied plus `implementation libs.spring.boot.starter`. Running `./gradlew :test-module:dependencies` showed `spring-boot-starter:3.5.3` in `compileClasspath`. The test-module was deleted and its `settings.gradle` include was removed before the final commit.

**Key finding:** Version catalog aliases with hyphens in `[versions]` create nested Groovy property accessors, not camelCase. `spring-boot` is accessed as `libs.versions.spring.boot.get()` (not `libs.versions.springBoot.get()`). Future subproject `build.gradle` files should use the library aliases (`libs.spring.boot.starter`) which work correctly via the generated type-safe API.

---

## Outstanding follow-ups

None.
