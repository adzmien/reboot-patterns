# Deploy Prometheus and Grafana

Status: done 2026-05-13

## Spec Reference

ISSUE-7 from `docs/specs/spec-curriculum-setup.md`

## What to build

Write Prometheus manifests in `infra/k8s/prometheus/` (ConfigMap: `prometheus.yml` with global scrape interval 15s and a Kubernetes SD config scraping pods annotated `prometheus.io/scrape: "true"` in `reboot-patterns`; Deployment: `prom/prometheus:v3.3.1`; NodePort Service 30090). Write Grafana manifests in `infra/k8s/grafana/` (ConfigMap: datasource provisioning pointing to Prometheus in-cluster; Deployment: `grafana/grafana:11.6.1`; NodePort Service 30030). No pre-built dashboards — those are deferred to Pattern 8.

## Acceptance Criteria

- [ ] Both Prometheus and Grafana pods are `Running`
- [ ] `curl -s http://100.66.8.44:30090/-/ready` returns HTTP 200
- [ ] Prometheus `/targets` page shows the Kubernetes SD job active (even if no scrape targets yet)
- [ ] `curl -s http://100.66.8.44:30030/api/health` returns `{"database":"ok"}`
- [ ] Grafana UI lists Prometheus as a pre-provisioned datasource

## Blocked by

None — can start immediately
