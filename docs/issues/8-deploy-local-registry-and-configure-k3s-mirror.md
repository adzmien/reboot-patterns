# Deploy local registry and configure k3s mirror

## Spec Reference

ISSUE-8 from `docs/specs/spec-curriculum-setup.md`

## What to build

Write registry manifests in `infra/k8s/registry/` (Deployment: `registry:2` with emptyDir volume; NodePort Service 30500). Configure `/etc/rancher/k3s/registries.yaml` on the Rocky Linux node to mirror `100.66.8.44:30500` → `localhost:30500`, then restart the k3s service. Document the manual node setup steps in `infra/k8s/registry/README.md`. **Prerequisite: port 30500 must be opened on the Tailscale/firewall layer before testing the push.**

## Acceptance Criteria

- [ ] Registry pod is `Running` after `kubectl apply -f infra/k8s/registry/`
- [ ] `docker push 100.66.8.44:30500/test-nginx:latest` from Mac succeeds with no auth errors
- [ ] A pod spec with `image: localhost:30500/test-nginx:latest` starts successfully in `reboot-patterns`
- [ ] Deleting and re-creating the pod pulls from the local registry without `ImagePullBackOff`
- [ ] `infra/k8s/registry/README.md` documents the `registries.yaml` setup and port 30500 firewall requirement

## Blocked by

None — can start immediately
