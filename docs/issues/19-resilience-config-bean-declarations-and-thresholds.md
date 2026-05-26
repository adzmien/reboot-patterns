# ResilienceConfig — Bean Declarations + application.properties Thresholds

## Spec Reference
ISSUE-6 from `docs/specs/spec-p2-resilience.md`

## What to build

Create `ResilienceConfig` with explicit `@Bean` definitions for all four Resilience4j instances for the `payment` policy. All thresholds must live in `application.properties` as named, commented properties — this is the single configuration surface a learner reads to understand what each number means.

Deliverables:
- `ResilienceConfig.java` — `@Configuration`; `@Bean` for `CircuitBreaker`, `Retry`, `TimeLimiter`, `Bulkhead` all named `payment`; 1-line "why this exists" comment: `// Declares the four defences that wrap every outbound payment call; thresholds are in application.properties.`
- `application.properties` additions (with inline comments explaining each value):
  ```properties
  # Circuit breaker: opens when 3 of the last 5 calls fail (60%) or are slow (>1s)
  resilience4j.circuitbreaker.instances.payment.sliding-window-size=5
  resilience4j.circuitbreaker.instances.payment.minimum-number-of-calls=5
  resilience4j.circuitbreaker.instances.payment.failure-rate-threshold=60
  resilience4j.circuitbreaker.instances.payment.slow-call-duration-threshold=1s
  resilience4j.circuitbreaker.instances.payment.slow-call-rate-threshold=80
  # Wait 10s in open state before allowing probe calls through
  resilience4j.circuitbreaker.instances.payment.wait-duration-in-open-state=10s
  resilience4j.circuitbreaker.instances.payment.permitted-number-of-calls-in-half-open-state=2
  # Retry: up to 3 total attempts (1 original + 2 retries), 200ms between attempts
  resilience4j.retry.instances.payment.max-attempts=3
  resilience4j.retry.instances.payment.wait-duration=200ms
  # Timeout: give up on any single payment call after 1s
  resilience4j.timelimiter.instances.payment.timeout-duration=1s
  # Bulkhead: cap concurrent in-flight payment calls at 10; reject the 11th immediately
  resilience4j.bulkhead.instances.payment.max-concurrent-calls=10
  resilience4j.bulkhead.instances.payment.max-wait-duration=0ms
  ```

## Acceptance Criteria

- [ ] Application context loads without errors with all four beans declared
- [ ] `GET /actuator/health` includes a `circuitBreakers` component showing `payment` in `CLOSED` state
- [ ] `GET /actuator/prometheus` includes `resilience4j_circuitbreaker_state{name="payment"}` metric
- [ ] All thresholds are visible in `application.properties` with inline comments — no threshold hardcoded in Java

## Blocked by

- #14
