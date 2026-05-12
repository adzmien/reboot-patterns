#!/usr/bin/env bash
# infra/k8s/apply-all.sh
#
# Orchestrates the full shared infrastructure setup for reboot-patterns.
# Run this once after cloning, or re-run at any time — it is fully idempotent.
#
# What it does:
#   1. Creates the reboot-patterns namespace (no-op if already exists)
#   2. Applies all K8s manifests in dependency order
#   3. Waits for every StatefulSet and Deployment to reach Ready state
#   4. Smoke-checks every NodePort and the WireMock admin endpoint
#   5. Verifies the MariaDB schema exists
#
# Exit codes: 0 = success, 1 = any check or apply failed.
#
# NodePort host: 100.66.8.44 (Tailscale address of the Rocky Linux k3s node)

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────────────
NAMESPACE="reboot-patterns"
NODE_IP="100.66.8.44"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Helpers ────────────────────────────────────────────────────────────────────
log()   { echo "[apply-all] $*"; }
ok()    { echo "[apply-all] ✓ $*"; }
fail()  { echo "[apply-all] ✗ ERROR: $*" >&2; exit 1; }

# ── Step 1: Ensure namespace ───────────────────────────────────────────────────
log "Step 1: Ensuring namespace '${NAMESPACE}' exists"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml \
  | kubectl apply -f -
ok "Namespace '${NAMESPACE}' ready"

# ── Step 2: Apply manifests in dependency order ────────────────────────────────
#
# Dependency order rationale:
#   core infra (secrets+configs before statefulsets) → registry → observability → mocks
#
#   MariaDB:        secret → configmap → statefulset → service
#   Kafka:          statefulset → service
#   Redis:          secret → deployment → service
#   Registry:       deployment → service
#   Jaeger:         deployment → service
#   OTel Collector: configmap → deployment → service   (depends on Jaeger endpoint)
#   Prometheus:     rbac → configmap → deployment → service
#   Grafana:        configmap → deployment → service   (depends on Prometheus endpoint)
#   WireMock:       deployment → service

log "Step 2: Applying manifests"

apply_dir() {
  local dir="$1"
  log "  Applying ${dir}"
  kubectl apply -f "${dir}"
}

# Core persistence
apply_dir "${SCRIPT_DIR}/mariadb"
apply_dir "${SCRIPT_DIR}/kafka"
apply_dir "${SCRIPT_DIR}/redis"

# Local container registry
apply_dir "${SCRIPT_DIR}/registry"

# Observability stack (Jaeger first — OTel Collector exports to it)
apply_dir "${SCRIPT_DIR}/jaeger"
apply_dir "${SCRIPT_DIR}/otel-collector"
apply_dir "${SCRIPT_DIR}/prometheus"
apply_dir "${SCRIPT_DIR}/grafana"

# External-call mocking
apply_dir "${SCRIPT_DIR}/../../mocks/deployment"

ok "All manifests applied"

# ── Step 3: Wait for StatefulSets and Deployments to be Ready ─────────────────
log "Step 3: Waiting for StatefulSets to be Ready (timeout 300s each)"

rollout_statefulset() {
  local name="$1"
  log "  Waiting for statefulset/${name}"
  kubectl rollout status statefulset/"${name}" \
    -n "${NAMESPACE}" --timeout=300s \
    || fail "statefulset/${name} did not become Ready within 300s"
  ok "statefulset/${name} is Ready"
}

rollout_deployment() {
  local name="$1"
  log "  Waiting for deployment/${name}"
  kubectl rollout status deployment/"${name}" \
    -n "${NAMESPACE}" --timeout=300s \
    || fail "deployment/${name} did not become Ready within 300s"
  ok "deployment/${name} is Ready"
}

rollout_statefulset "mariadb"
rollout_statefulset "kafka"

log "Step 3b: Waiting for Deployments to be Ready (timeout 300s each)"
rollout_deployment "redis"
rollout_deployment "local-registry"
rollout_deployment "jaeger"
rollout_deployment "otel-collector"
rollout_deployment "prometheus"
rollout_deployment "grafana"
rollout_deployment "wiremock"

# ── Step 4: NodePort smoke checks ─────────────────────────────────────────────
log "Step 4: Smoke-checking NodePorts on ${NODE_IP}"

check_port() {
  local port="$1"
  local label="$2"
  log "  Checking ${label} on ${NODE_IP}:${port}"
  nc -zv "${NODE_IP}" "${port}" 2>&1 \
    || fail "NodePort ${port} (${label}) is unreachable — is the service Running and the firewall open?"
  ok "${label} NodePort ${port} reachable"
}

check_port 30306 "MariaDB"
check_port 30092 "Kafka"
check_port 30379 "Redis"
check_port 30080 "WireMock HTTP"
check_port 30686 "Jaeger UI"
check_port 30090 "Prometheus"
check_port 30030 "Grafana"
check_port 30500 "Local registry"

# ── Step 4b: WireMock admin endpoint ──────────────────────────────────────────
log "Step 4b: Checking WireMock admin endpoint"
curl -sf "http://${NODE_IP}:30080/__admin/mappings" -o /dev/null \
  || fail "WireMock admin endpoint http://${NODE_IP}:30080/__admin/mappings is not responding"
ok "WireMock admin endpoint responded"

# ── Step 5: MariaDB schema existence check ────────────────────────────────────
log "Step 5: Verifying MariaDB schema 'p1_gateway' exists"

SCHEMA_CHECK=$(
  mysql \
    --host="${NODE_IP}" \
    --port=30306 \
    --user=rebootuser \
    --password=abc@123 \
    --batch --silent \
    --execute="SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = 'p1_gateway';" \
    2>/dev/null
)

if [ -z "${SCHEMA_CHECK}" ]; then
  fail "MariaDB schema 'p1_gateway' does not exist — did the init.sql ConfigMap run correctly?"
fi
ok "MariaDB schema 'p1_gateway' exists (all pattern schemas created by init.sql)"

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
log "All checks passed. Shared infrastructure is up and healthy."
log "Run 'kubectl get pods -n ${NAMESPACE}' to see all running pods."
