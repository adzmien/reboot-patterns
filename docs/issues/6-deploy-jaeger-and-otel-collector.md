# Deploy Jaeger and OTel Collector

## Spec Reference

ISSUE-6 from `docs/specs/spec-curriculum-setup.md`

## What to build

Write Jaeger manifests in `infra/k8s/jaeger/` (Deployment: `jaegertracing/all-in-one:1.62.0`; Service: NodePort 30686 for UI + ClusterIP for OTLP port 4317). Write OTel Collector manifests in `infra/k8s/otel-collector/` (ConfigMap: minimal pipeline — OTLP gRPC receiver → Jaeger exporter; Deployment: `otel/opentelemetry-collector-contrib:0.123.0`; ClusterIP Service: 4317 gRPC + 4318 HTTP). The Collector exports to Jaeger via in-cluster hostname. Detailed instrumentation pipeline is deferred to Pattern 8 — only the base pipeline is wired here.

## Acceptance Criteria

- [ ] Both Jaeger and OTel Collector pods are `Running`
- [ ] `curl -s http://100.66.8.44:30686` returns HTTP 200 (Jaeger UI)
- [ ] A synthetic OTLP span sent to OTel Collector ClusterIP:4317 appears in Jaeger UI within 5 seconds
- [ ] OTel Collector ConfigMap references Jaeger by in-cluster hostname (not NodePort)

## Blocked by

None — can start immediately
