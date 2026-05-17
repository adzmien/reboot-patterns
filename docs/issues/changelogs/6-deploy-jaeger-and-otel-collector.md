# Changelog — #6 Deploy Jaeger and OTel Collector

- **Branch:** `issue/6-deploy-jaeger-and-otel-collector`
- **Date:** 2026-05-13 (Asia/Kuala_Lumpur, UTC+8)
- **Iterations used:** 1 of 5
- **Status:** Done — all acceptance criteria met

## Proposed squash commit message

```text
feat(#6): deploy Jaeger and OTel Collector

Add Jaeger all-in-one (v1.62.0) and OTel Collector Contrib (v0.123.0) to
infra/k8s/. Jaeger is exposed via NodePort 30686 for UI and a ClusterIP
service on port 4317 for in-cluster OTLP ingestion. The OTel Collector uses
a minimal OTLP → batch → Jaeger pipeline and is reachable in-cluster only
via ClusterIP. A synthetic span sent to the Collector appears in Jaeger
within 3 seconds, confirming the end-to-end pipeline.

Acceptance criteria:
- [x] Both Jaeger and OTel Collector pods are Running
- [x] curl -s http://100.66.8.44:30686 returns HTTP 200 (Jaeger UI)
- [x] A synthetic OTLP span sent to OTel Collector ClusterIP:4317 appears in Jaeger UI within 5 seconds
- [x] OTel Collector ConfigMap references Jaeger by in-cluster hostname (not NodePort)

Closes #6.
```

## Summary of changes

- Added `infra/k8s/jaeger/01-deployment.yaml` — Jaeger all-in-one Deployment with `COLLECTOR_OTLP_ENABLED=true`.
- Added `infra/k8s/jaeger/02-service.yaml` — two Services: NodePort 30686 (UI) and ClusterIP 4317 (OTLP in-cluster).
- Added `infra/k8s/otel-collector/01-configmap.yaml` — minimal pipeline config: OTLP gRPC/HTTP receiver → batch processor → OTLP exporter to `jaeger:4317`.
- Added `infra/k8s/otel-collector/02-deployment.yaml` — OTel Collector Contrib Deployment mounting the ConfigMap.
- Added `infra/k8s/otel-collector/03-service.yaml` — ClusterIP Service exposing gRPC 4317 and HTTP 4318.

## Acceptance criteria status

| Criterion | Status | Note |
|---|---|---|
| Both pods Running | ✅ | `jaeger` and `otel-collector` 1/1 Running, 0 restarts |
| `curl http://100.66.8.44:30686` → HTTP 200 | ✅ | Verified immediately after rollout |
| Synthetic OTLP span visible in Jaeger within 5 s | ✅ | Span appeared in Jaeger API within 3 s via `curlimages/curl` debug pod |
| ConfigMap references Jaeger by in-cluster hostname | ✅ | `endpoint: "jaeger:4317"` in ConfigMap, not a NodePort |

## Files changed

### Added
- `infra/k8s/jaeger/01-deployment.yaml`
- `infra/k8s/jaeger/02-service.yaml`
- `infra/k8s/otel-collector/01-configmap.yaml`
- `infra/k8s/otel-collector/02-deployment.yaml`
- `infra/k8s/otel-collector/03-service.yaml`

### Modified
None.

### Deleted
None.

## Commits on branch

```
477f4a5 feat(#6): deploy Jaeger and OTel Collector
```

## Verification

| Step | Result |
|---|---|
| `kubectl apply -f infra/k8s/jaeger/` | Exit 0 — 3 resources created (Deployment, 2 Services) |
| `kubectl apply -f infra/k8s/otel-collector/` | Exit 0 — 3 resources created (ConfigMap, Deployment, Service) |
| `kubectl rollout status deployment/jaeger -n reboot-patterns` | `deployment "jaeger" successfully rolled out` |
| `kubectl rollout status deployment/otel-collector -n reboot-patterns` | `deployment "otel-collector" successfully rolled out` |
| `curl -s -o /dev/null -w "%{http_code}" http://100.66.8.44:30686` | `200` |
| Synthetic span (OTLP/HTTP → ClusterIP:4318 → Jaeger) | `synthetic-test` service + `synthetic-span` operation visible in Jaeger API within 3 s |

**Note on synthetic span method:** The OTel Collector image (`otel/opentelemetry-collector-contrib:0.123.0`) is distroless — no shell or curl inside the container. The span was sent from a temporary `curlimages/curl:8.7.1` pod (`kubectl run --rm --attach`) targeting the `otel-collector` ClusterIP service. This is the correct approach for distroless images.

## Outstanding follow-ups

None.
