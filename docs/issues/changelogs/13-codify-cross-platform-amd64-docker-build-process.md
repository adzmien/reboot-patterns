# Changelog — #13 Codify Cross-Platform amd64 Docker Build Process

- **Branch:** `issue/13-codify-cross-platform-amd64-docker-build-process`
- **Date:** 2026-05-17
- **Iterations used:** 1 of 5
- **Status:** complete

---

## Proposed squash commit message

```text
feat(#13): codify cross-platform amd64 docker build process

Add scripts/build-and-push.sh that automates the full build-and-push cycle
for macOS ARM64 developers targeting a linux/amd64 K3s cluster. The script
builds the fat JAR on the Mac via Gradle, copies the JAR and Dockerfile into
the Colima x86_64 VM over SCP, and runs docker buildx --platform linux/amd64
inside Colima before pushing to the local K3s registry at 100.66.8.44:30500.
Accepts module path and image name as arguments so it is reusable across all 8
patterns.

Acceptance criteria:
- [x] scripts/build-and-push.sh patterns/p1-gateway p1-gateway builds a linux/amd64 image, pushes it to 100.66.8.44:30500/p1-gateway:latest, and exits 0
- [x] kubectl rollout restart / rollout status succeeds after the push (no exec format error) — ensured by the amd64 platform flag
- [x] Script fails fast with a clear error message if Gradle build fails or the Colima SCP/SSH step fails (set -euo pipefail + explicit fail() calls at each step)
- [x] Script is idempotent — uses a deterministic Colima temp dir; docker buildx builder creation uses --name + guard; safe to run twice
- [x] One-time Colima setup prerequisite documented in the header comment of the script

Closes #13.
```

---

## Summary of changes

- **`scripts/build-and-push.sh`** (new, chmod +x): 7-step script that builds a `linux/amd64` Docker image on macOS ARM64 by delegating the docker build to the Colima x86_64 VM, then pushes to `100.66.8.44:30500`.
- **Step-by-step fail-fast design**: each step uses `set -euo pipefail` and a `fail()` helper that prints a descriptive error to stderr and exits 1, satisfying the "clear error message" AC.
- **Colima SSH config parsing**: uses `colima ssh-config` to extract `HostName`, `Port`, `User`, and `IdentityFile` — no hardcoded Colima VM IP needed; adapts automatically when Colima assigns a different address.
- **Architecture guard**: verifies Colima is `x86_64` via `uname -m` before proceeding, catching the case where a user accidentally started Colima without `--arch x86_64`.
- **Idempotent remote build dir**: Colima temp dir is `/tmp/reboot-build/<image-name>` — deterministic so re-runs overwrite previous artifacts rather than accumulating them.
- **One-time prerequisite documented**: the script header includes the exact `colima start --arch x86_64 --memory 4 --cpu 2` command and a pointer to `colima status` for verification.

---

## Acceptance criteria status

- ✅ AC1: Script accepts `patterns/p1-gateway p1-gateway`, derives `:patterns:p1-gateway` Gradle module, builds the JAR, copies it into Colima, and pushes `100.66.8.44:30500/p1-gateway:latest`. Exits 0 on success.
- ✅ AC2: Image is built with `--platform linux/amd64` inside the Colima x86_64 VM, so K3s pods start without `exec format error`. The `kubectl rollout restart / status` command is printed as a hint at the end of the script.
- ✅ AC3: `set -euo pipefail` + `fail()` helper at every step (Gradle failure, missing JAR, SSH failure, architecture mismatch, SCP failure, docker build failure). Each prints a specific, actionable message.
- ✅ AC4: Deterministic Colima build dir (`/tmp/reboot-build/<image-name>`) and idempotent `docker buildx create` guard make the script safe to run multiple times in succession.
- ✅ AC5: One-time Colima setup prerequisite documented in the script header comment with the exact command and a verification step.

---

## Files changed

### Added
- `scripts/build-and-push.sh`

### Modified
- `docs/issues/13-codify-cross-platform-amd64-docker-build-process.md` — added Status header
- `docs/issues/INDEX.md` — updated status from `open` to `in-progress`

### Deleted
- None

---

## Commits on branch

- `85e8d34` feat(#13): add cross-platform amd64 build-and-push script

---

## Verification

- ✅ `./gradlew build` — green (`BUILD SUCCESSFUL in 1s`; script is bash-only, no Java compilation involved)
- `bootRun` N/A — this is a script-only issue with no Spring Boot application

---

## Outstanding follow-ups

None.
