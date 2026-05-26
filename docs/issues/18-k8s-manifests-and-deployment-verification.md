# K8s Manifests + Deployment Verification

## Spec Reference
ISSUE-5 from `docs/specs/spec-p2-resilience.md`

## What to build

Write the Kubernetes manifests for the `order` service, build and push the image, deploy to the `reboot-patterns` namespace, and verify the service is reachable via both its direct NodePort and through the gateway.

Deliverables:
- `patterns/p2-resilience/k8s/01-deployment.yaml` — 1 replica; image `localhost:30500/p2-order:latest`; ports 8080 (app) and 8081 (actuator); readiness probe `GET /actuator/health` (initial delay 15s, period 10s); liveness probe (initial delay 30s, period 20s)
- `patterns/p2-resilience/k8s/02-service.yaml` — NodePort 30002 → 8080 (app), NodePort 30082 → 8081 (actuator); service name `order` (so `lb://order` in the gateway resolves correctly)

Build and push via `scripts/build-and-push.sh` (linux/amd64 via Colima).

## Acceptance Criteria

- [ ] `GET http://localhost:30082/actuator/health` returns `{"status":"UP"}` after deployment
- [ ] `POST http://localhost:30002/orders` (direct NodePort) returns a valid response against a healthy WireMock stub
- [ ] `POST http://localhost:30001/orders` (via gateway) returns a valid response with `X-Correlation-ID` injected by the gateway
- [ ] `kubectl get svc -n reboot-patterns` shows `order` service with NodePorts 30002 and 30082
- [ ] No NodePort conflicts (verify 30002/30082 are free before applying)

## Blocked by

- #17
