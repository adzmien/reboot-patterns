#!/usr/bin/env bash
# reset.sh — idempotent reset for p1-gateway tests.
# Must be sourced at the start of every p1 test script.
NODE_IP="100.66.8.44"

echo "p1-gateway reset: clearing WireMock stubs for pattern p1"
curl -sf "http://${NODE_IP}:30080/__admin/mappings" \
  | jq -r '.mappings[] | select(.metadata.pattern == "p1") | .id' \
  | while read -r id; do
      curl -sf -X DELETE "http://${NODE_IP}:30080/__admin/mappings/${id}" > /dev/null
    done

echo "p1-gateway reset: re-applying stub K8s Services"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "${SCRIPT_DIR}/../../patterns/p1-gateway/k8s/stub-services.yaml" \
  || { echo "ERROR: failed to apply stub-services.yaml"; exit 1; }

echo "p1-gateway reset complete"
