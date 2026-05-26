# canonical-failure.sh — Full Circuit Breaker Lifecycle

## Spec Reference
ISSUE-10 from `docs/specs/spec-p2-resilience.md`

## What to build

Write `tests/p2-resilience/canonical-failure.sh`. This is the **definition-of-done gate** for p2-resilience. The script drives the complete "slow downstream → timeout → open → fast-fail → half-open → recover" cycle against the live Kubernetes cluster.

The script must `source ./tests/p2-resilience/reset.sh` as its first action, then execute these 9 steps in order. Each step must echo `"Step N: <action>"` before executing and `exit 1` on assertion failure.

| Step | Action | Assertion |
|------|--------|-----------|
| 1 | `source reset.sh` | Exits 0 |
| 2 | POST WireMock stub: `POST /payments` → `200 {"result":"approved"}`, metadata `{"pattern":"p2"}` | HTTP 201 from WireMock admin |
| 3 | `POST /orders {"itemId":"ITEM-1","quantity":1}` with `X-Correlation-ID: test-corr-1` | HTTP 200; body contains `"ACCEPTED"`; WireMock request log shows `X-Correlation-ID: test-corr-1` |
| 4 | Update WireMock stub: add `fixedDelayMilliseconds: 1500` | Stub updated (200) |
| 5 | Drive 5 × `POST /orders` (each with a unique correlation ID) | Each returns HTTP 503; each response arrives in < 1100ms |
| 6 | Drive 1 × `POST /orders` | HTTP 503; body contains `"circuit_open"`; response time < 50ms |
| 7 | `sleep 12` | — (wait for 10s open state + 2s margin) |
| 8 | Update WireMock stub: remove delay (`fixedDelayMilliseconds: 0`) | Stub updated |
| 9 | Drive 2 × `POST /orders` (probe calls) | Both return HTTP 200; WireMock request log shows `X-Correlation-ID` present on **all** requests from steps 3, 5, and 9 (including retry attempts from step 5) |

Correlation-ID assertion (step 9): `GET http://localhost:30080/__admin/requests | jq '[.requests[].request.headers["X-Correlation-ID"]] | map(select(. != null)) | length'` — assert count equals total expected requests.

## Acceptance Criteria

- [ ] `bash tests/p2-resilience/canonical-failure.sh` exits 0 against the running cluster
- [ ] Fast-fail response in step 6 arrives in under 50ms
- [ ] Recovery in step 9 produces HTTP 200 (circuit closed)
- [ ] All WireMock request log entries (including retried attempts from step 5) carry a non-null `X-Correlation-ID`
- [ ] Script narrates every step with `echo "Step N: <action>"` before executing

## Blocked by

- #21
- #22
