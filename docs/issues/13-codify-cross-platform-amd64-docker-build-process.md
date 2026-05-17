# Codify Cross-Platform amd64 Docker Build Process

Status: done 2026-05-18

## Spec Reference

Operational follow-up — no spec ISSUE. Surfaced during #11 implementation.

## What to build

The dev machine is macOS ARM64 (Apple Silicon). The K3s node (`100.66.8.44`) is `linux/amd64`. A plain `docker build` on the Mac produces an ARM64 image that crashes in K3s with `exec format error`.

Create a `build-and-push.sh` helper script at the repo root (or per-pattern) that encapsulates the full cross-platform build-and-push cycle:

1. `./gradlew :<module>:bootJar` — compile the fat JAR on the Mac
2. `scp` the JAR into the Colima VM (which runs `linux/amd64`)
3. SSH into Colima and run `docker buildx build --platform linux/amd64 -t <registry>/<image>:latest --push` using the Dockerfile and the SCP'd JAR

The script must accept the Gradle module path and image name as arguments so it can be reused by all 8 patterns.

**Suggested interface:**
```bash
./scripts/build-and-push.sh patterns/p1-gateway p1-gateway
```

**Script location:** `scripts/build-and-push.sh`

## Acceptance Criteria

- [ ] `scripts/build-and-push.sh patterns/p1-gateway p1-gateway` builds a `linux/amd64` image, pushes it to `100.66.8.44:30500/p1-gateway:latest`, and exits 0
- [ ] `kubectl rollout restart deployment/p1-gateway -n reboot-patterns && kubectl rollout status deployment/p1-gateway -n reboot-patterns --timeout=90s` succeeds after the push (pod runs — no `exec format error`)
- [ ] The script fails fast with a clear error message if the Gradle build fails or the Colima SCP/SSH step fails
- [ ] The script is idempotent — safe to run twice in succession
- [ ] `README.md` or a comment in the script documents the one-time Colima setup prerequisite (Colima must be running with `colima start --arch x86_64`)

## Blocked by

- #11
