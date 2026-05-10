# Adapt and deploy Kafka to reboot-patterns

## Spec Reference

ISSUE-3 from `docs/specs/spec-curriculum-setup.md`

## What to build

Adapt Kafka K8s manifests from `com-reboot/reboot-common-k8s/kafka/` into `infra/k8s/kafka/`. Change namespace to `reboot-patterns`. Verify `KAFKA_ADVERTISED_LISTENERS` is set to `PLAINTEXT://100.66.8.44:30092` (Tailscale IP). Keep image (`apache/kafka:3.9.0`), KRaft config, and PVC size (2Gi) unchanged. NodePort 30092 must be reachable from Mac.

## Acceptance Criteria

- [ ] Kafka pod is `Running` after `kubectl apply -f infra/k8s/kafka/`
- [ ] `nc -zv 100.66.8.44 30092` succeeds from Mac
- [ ] A producer can connect to `100.66.8.44:30092` and publish a test message without error
- [ ] A consumer on the same broker receives that test message

## Blocked by

None — can start immediately
