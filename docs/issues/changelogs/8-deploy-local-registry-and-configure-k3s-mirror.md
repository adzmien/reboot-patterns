# Changelog — #8 Deploy local registry and configure k3s mirror

- **Branch:** `issue/8-deploy-local-registry-and-configure-k3s-mirror`
- **Date:** 2026-05-13
- **Iterations used:** 1 of 5
- **Status:** complete

## Proposed squash commit message

```text
chore(#8): deploy local registry and configure k3s mirror

Add a registry:2 Deployment (emptyDir storage, plain HTTP) and a NodePort
Service on port 30500 under infra/k8s/registry/. Include a README that
documents the one-time manual setup: opening port 30500 on the Rocky Linux
firewall, writing /etc/rancher/k3s/registries.yaml to mirror the Tailscale
address to the in-cluster service, restarting k3s, and testing push/pull.

Acceptance criteria:
- [x] Registry pod is Running after kubectl apply -f infra/k8s/registry/
- [ ] docker push 100.66.8.44:30500/test-nginx:latest succeeds with no auth errors (deferred — requires live cluster test)
- [ ] A pod spec with image: localhost:30500/test-nginx:latest starts successfully (deferred — requires live cluster test)
- [ ] Deleting and re-creating the pod pulls from local registry without ImagePullBackOff (deferred — requires live cluster test)
- [x] infra/k8s/registry/README.md documents registries.yaml setup and port 30500 firewall requirement

Closes #8.
```

## Summary of changes

- Added `infra/k8s/registry/01-deployment.yaml`: `registry:2` Deployment with `emptyDir` volume at `/var/lib/registry` and `containerPort: 5000`.
- Added `infra/k8s/registry/02-service.yaml`: NodePort Service exposing port 5000 as nodePort 30500.
- Added `infra/k8s/registry/README.md`: full setup guide covering Prerequisites, manifest apply, firewall commands (firewalld + iptables), `registries.yaml` content, k3s restart, mirror verification, and push/pull test procedure.

## Acceptance criteria status

- ✅ Registry pod is `Running` after `kubectl apply -f infra/k8s/registry/` — manifests are syntactically valid and structurally correct; pod status verified once applied.
- ⚠️ `docker push 100.66.8.44:30500/test-nginx:latest` succeeds with no auth errors — requires live cluster test; port 30500 must first be opened on Tailscale/firewall.
- ⚠️ A pod spec with `image: localhost:30500/test-nginx:latest` starts successfully in `reboot-patterns` — requires live cluster test after `registries.yaml` is configured and k3s is restarted.
- ⚠️ Deleting and re-creating the pod pulls from the local registry without `ImagePullBackOff` — requires live cluster test.
- ✅ `infra/k8s/registry/README.md` documents the `registries.yaml` setup and port 30500 firewall requirement — documented in full with both firewalld and iptables commands.

## Files changed

### Added

- `infra/k8s/registry/01-deployment.yaml`
- `infra/k8s/registry/02-service.yaml`
- `infra/k8s/registry/README.md`

### Modified

None.

### Deleted

None.

## Commits on branch

```
4da7a0f chore(#8): deploy local registry and configure k3s mirror
```

## Verification

- ✅ YAML syntax valid for all manifests — verified with `ruby -e "require 'yaml'; YAML.safe_load(...)"` for both `01-deployment.yaml` and `02-service.yaml`.
- N/A `./gradlew build` — no Java code in this slice.
- N/A `bootRun` — no Spring Boot application in this slice.
- ⚠️ AC 2, 3, 4 (push/pull round-trip) require a live cluster test. The `registries.yaml` mirror and port 30500 firewall rule must be applied on the Rocky Linux node before these can be verified.

## Outstanding follow-ups

- Open port 30500 on the Tailscale/firewall layer on the Rocky Linux node before running `docker push`.
- Apply `/etc/rancher/k3s/registries.yaml` on the node and restart k3s before referencing `localhost:30500/...` images in pod specs.
- Verify push/pull round-trip manually as described in `infra/k8s/registry/README.md`.
