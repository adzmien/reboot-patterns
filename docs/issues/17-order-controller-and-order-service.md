# OrderController + OrderService

## Spec Reference
ISSUE-4 from `docs/specs/spec-p2-resilience.md`

## What to build

Implement the `POST /orders` HTTP endpoint end-to-end: controller validates the request, service persists the order, calls payment, and updates status. After this issue, the full happy path works against the live WireMock stub.

Deliverables:
- `OrderController.java` — `@RestController`; `POST /orders` accepts `{"itemId": "...", "quantity": N}`; reads `X-Correlation-ID` from the inbound request header and passes it to `OrderService`; returns `200 {"orderId": N, "status": "ACCEPTED"}` on success or `503 {"error": "payment_unavailable"}` on payment failure; `400` on missing/invalid body
- `OrderService.java` — `@Service`; `placeOrder(String itemId, int quantity, String correlationId)`; (1) inserts `Order` with status `PENDING`, (2) calls `PaymentClient.requestPayment()`, (3) updates status to `ACCEPTED` or `FAILED`; 1-line "why this exists" comment: `// Orchestrates order placement: persists intent, calls payment, records outcome.`

## Acceptance Criteria

- [ ] `POST /orders {"itemId":"ITEM-1","quantity":1}` with a healthy WireMock stub returns `200 {"orderId": <id>, "status": "ACCEPTED"}`
- [ ] `POST /orders` with a WireMock stub returning `500` returns `503 {"error": "payment_unavailable"}`
- [ ] `POST /orders` with a missing body returns `400`
- [ ] The `X-Correlation-ID` from the inbound request is forwarded to the WireMock payment stub (verify via `GET http://localhost:30080/__admin/requests`)
- [ ] Commit follows convention: `pattern(p2-resilience): add OrderController, OrderService, and plain PaymentClient`

## Blocked by

- #15
- #16
