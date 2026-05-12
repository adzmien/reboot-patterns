# Changelog — #7 Deploy Prometheus and Grafana

- **Branch:** `issue/7-deploy-prometheus-and-grafana`
- **Date:** 2026-05-13
- **Iterations used:** 1 of 5
- **Status:** complete

## Proposed squash commit message

```text
feat(#7): deploy Prometheus and Grafana

Add Prometheus (prom/prometheus:v3.3.1) with RBAC manifests (ServiceAccount,
ClusterRole, ClusterRoleBinding) and a Kubernetes pod SD config that scrapes
any pod annotated prometheus.io/scrape: "true" in the reboot-patterns namespace.
Add Grafana (grafana/grafana:11.6.1) with a provisioning ConfigMap that
auto-registers Prometheus as the default datasource via its in-cluster ClusterIP
hostname. No pre-built dashboards — those are deferred to Pattern 8.

Acceptance criteria:
- [x] Both Prometheus and Grafana pods are Running
- [x] curl -s http://100.66.8.44:30090/-/ready returns HTTP 200
- [x] Prometheus /targets page shows the kubernetes-pods SD job active
- [x] curl -s http://100.66.8.44:30030/api/health returns {"database":"ok"}
- [x] Grafana UI lists Prometheus as a pre-provisioned datasource

Closes #7.
```

## Summary of changes

- Added `infra/k8s/prometheus/01-rbac.yaml` — ServiceAccount, ClusterRole, and ClusterRoleBinding so Prometheus can call the Kubernetes API to discover pods.
- Added `infra/k8s/prometheus/02-configmap.yaml` — `prometheus.yml` with 15s global scrape interval and a `kubernetes_sd_configs` job that discovers and relabels pods annotated `prometheus.io/scrape: "true"`.
- Added `infra/k8s/prometheus/03-deployment.yaml` — single-replica Deployment running `prom/prometheus:v3.3.1` with the ConfigMap mounted; 7-day TSDB retention.
- Added `infra/k8s/prometheus/04-service.yaml` — NodePort 30090 for external access plus a ClusterIP `prometheus:9090` for Grafana in-cluster communication.
- Added `infra/k8s/grafana/01-configmap.yaml` — datasource provisioning file that auto-creates the Prometheus datasource at `http://prometheus:9090` on startup.
- Added `infra/k8s/grafana/02-deployment.yaml` — single-replica Deployment running `grafana/grafana:11.6.1` with the provisioning ConfigMap mounted; default `admin:admin` credentials.
- Added `infra/k8s/grafana/03-service.yaml` — NodePort 30030 exposing the Grafana UI externally.

## Acceptance criteria status

- ✅ Both Prometheus and Grafana pods are `Running` — verified with `kubectl get pods -n reboot-patterns`; both 1/1 Running, 0 restarts.
- ✅ `curl -s http://100.66.8.44:30090/-/ready` returns HTTP 200 — confirmed immediately after rollout.
- ✅ Prometheus `/targets` shows the kubernetes-pods SD job active — `kubernetes-pods` scrape pool visible with multiple discovered targets across the namespace.
- ✅ `curl -s http://100.66.8.44:30030/api/health` returns `{"database":"ok"}` — response also includes `"version":"11.6.1"`.
- ✅ Grafana UI lists Prometheus as a pre-provisioned datasource — `/api/datasources` returns the Prometheus entry with `isDefault:true` and `url:"http://prometheus:9090"`.

## Files changed

### Added
- `infra/k8s/grafana/01-configmap.yaml`
- `infra/k8s/grafana/02-deployment.yaml`
- `infra/k8s/grafana/03-service.yaml`
- `infra/k8s/prometheus/01-rbac.yaml`
- `infra/k8s/prometheus/02-configmap.yaml`
- `infra/k8s/prometheus/03-deployment.yaml`
- `infra/k8s/prometheus/04-service.yaml`

### Modified
None.

### Deleted
None.

## Commits on branch

```
c8b8847 feat(#7): deploy Prometheus and Grafana
```

## Verification

- ✅ `kubectl apply -f infra/k8s/prometheus/` — 7 resources created (ServiceAccount, ClusterRole, ClusterRoleBinding, ConfigMap, Deployment, 2 Services), exit 0
- ✅ `kubectl apply -f infra/k8s/grafana/` — 3 resources created (ConfigMap, Deployment, Service), exit 0
- ✅ Both pods Running — `prometheus-5566575567-qrd4p` 1/1 Running, `grafana-85fd795459-d2p2x` 1/1 Running
- ✅ `curl http://100.66.8.44:30090/-/ready` — HTTP 200
- ✅ `curl http://100.66.8.44:30030/api/health` — `{"database":"ok","version":"11.6.1","commit":"ae23ead4d959aa73a5a0ffada60e4147d679523c"}`
- ✅ Prometheus kubernetes-pods SD job visible in /targets — job active, multiple pods discovered from the reboot-patterns namespace
- ✅ Grafana datasource pre-provisioned — `/api/datasources` returns Prometheus entry: `isDefault:true`, `url:"http://prometheus:9090"`, `readOnly:true`

## Outstanding follow-ups

None.
