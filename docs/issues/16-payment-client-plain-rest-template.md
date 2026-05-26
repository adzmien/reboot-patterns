# PaymentClient with Plain RestTemplate

## Spec Reference
ISSUE-3 from `docs/specs/spec-p2-resilience.md`

## What to build

Implement `PaymentClient` and `RestTemplateConfig`. This is the outbound HTTP call to the WireMock `payment` stub, with no Resilience4j decoration yet. Resilience4j wrapping is added in a later issue — keeping this plain first makes the decoration step easier to understand and diff.

Deliverables:
- `RestTemplateConfig.java` — `@Configuration` with a single `RestTemplate` `@Bean`
- `PaymentClient.java` — `@Component`; reads `payment.base-url` from `application.properties`; exposes `requestPayment(PaymentRequest request, String correlationId)`; sets `X-Correlation-ID` header on every outbound call; returns `PaymentResult` (success/failure discriminated type); 1-line "why this exists" comment: `// Outbound call to the payment service; this is the call that all four Resilience4j defences will wrap.`
- `application.properties`: add `payment.base-url=http://payment:8080`
- `PaymentRequest` and `PaymentResult` value types (records or simple POJOs)

`PaymentResult` must distinguish at minimum: success and unavailable. The circuit-open and capacity-exhausted variants are added in the Resilience4j decoration issue.

## Acceptance Criteria

- [ ] A call to a WireMock stub returning `200 {"result":"approved"}` produces a successful `PaymentResult`
- [ ] The outbound request carries the `X-Correlation-ID` header matching the value passed into `requestPayment`
- [ ] A call to a WireMock stub returning `500` propagates as a failure `PaymentResult` (not an uncaught exception reaching the controller)
- [ ] `payment.base-url` is read from `application.properties` (not hardcoded in the class)

## Blocked by

- #14
