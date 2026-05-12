# mocks/stubs — Permanent Cross-Pattern Stubs

This directory holds **permanent, cross-pattern WireMock stub JSON files** that are loaded once at WireMock boot and remain in place for the lifetime of the cluster.

## Purpose

Some external APIs are called by multiple patterns. Rather than each pattern's `reset.sh` re-registering the same stub, these shared stubs are loaded once via WireMock's `--root-dir` or a startup script, and are never deleted by per-pattern cleanup.

## Planned permanent stubs

| File | Mocked service | Used by patterns |
|---|---|---|
| `payment-gateway.json` | Mock payment gateway (POST `/payments`) | p3-outbox, p4-saga-choreography, p5-saga-orchestration, p7-idempotency-dlq |
| `email-gateway.json` | Mock email/notification gateway (POST `/notifications/email`) | p3-outbox, p4-saga-choreography, p5-saga-orchestration |

## Rules

- **No stub JSON files yet.** Stub files are added here only when the first pattern that requires them is implemented (via `/pick-issue`).
- Each stub file MUST set `metadata.permanent: true` so per-pattern `reset.sh` scripts (which filter by `metadata.pattern: p<N>`) do not accidentally delete them.
- Per-pattern stubs are **not** stored here. They are registered at test setup time by each pattern's bash test script and removed at teardown via `DELETE /__admin/mappings` filtered by `metadata.pattern: p<N>`.

## WireMock admin API quick reference

```bash
# List all active mappings
curl -s http://<node>:30080/__admin/mappings

# Register a stub
curl -s -X POST http://<node>:30080/__admin/mappings \
  -H "Content-Type: application/json" \
  -d @payment-gateway.json

# Delete stubs for a specific pattern only
curl -s -X DELETE "http://<node>:30080/__admin/mappings" \
  -H "Content-Type: application/json" \
  -d '{"metadata": {"pattern": "p1"}}'
```
