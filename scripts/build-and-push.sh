#!/usr/bin/env bash
# scripts/build-and-push.sh
#
# Why this exists: the dev machine is macOS ARM64 (Apple Silicon) but the K3s
# node (100.66.8.44) runs linux/amd64. A plain `docker build` on the Mac
# produces an ARM64 image that crashes in K3s with "exec format error". This
# script solves that by:
#   1. Building the fat JAR on the Mac with Gradle (fast, native)
#   2. Copying the JAR + Dockerfile into the Colima VM (which is linux/amd64)
#   3. Running `docker buildx build --platform linux/amd64` inside Colima
#   4. Pushing the amd64 image to the local K3s registry (100.66.8.44:30500)
#
# One-time prerequisite: Colima must be running as an x86_64 VM.
#   colima start --arch x86_64 --memory 4 --cpu 2
# Verify with: colima status
#
# Usage:
#   ./scripts/build-and-push.sh <module-path> <image-name>
#
# Examples:
#   ./scripts/build-and-push.sh patterns/p1-gateway p1-gateway
#   ./scripts/build-and-push.sh patterns/p3-outbox  p3-outbox
#
# Arguments:
#   module-path   Relative path to the subproject, e.g. patterns/p1-gateway
#   image-name    Docker image name (without registry prefix), e.g. p1-gateway

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────────────
REGISTRY="100.66.8.44:30500"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Helpers ────────────────────────────────────────────────────────────────────
log()  { echo "[build-and-push] $*"; }
ok()   { echo "[build-and-push] ✓ $*"; }
fail() { echo "[build-and-push] ✗ ERROR: $*" >&2; exit 1; }

# ── Argument validation ────────────────────────────────────────────────────────
if [ "${#}" -lt 2 ]; then
  fail "Usage: $0 <module-path> <image-name>
  Example: $0 patterns/p1-gateway p1-gateway"
fi

MODULE_PATH="${1}"   # e.g. patterns/p1-gateway
IMAGE_NAME="${2}"    # e.g. p1-gateway

# Derive the Gradle module path: patterns/p1-gateway → :patterns:p1-gateway
GRADLE_MODULE=":$(echo "${MODULE_PATH}" | tr '/' ':')"

# Absolute path to the subproject on the Mac
MODULE_ABS="${REPO_ROOT}/${MODULE_PATH}"

if [ ! -d "${MODULE_ABS}" ]; then
  fail "Module directory not found: ${MODULE_ABS}"
fi

DOCKERFILE="${MODULE_ABS}/Dockerfile"
if [ ! -f "${DOCKERFILE}" ]; then
  fail "Dockerfile not found: ${DOCKERFILE}"
fi

FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:latest"

log "Module path  : ${MODULE_PATH}"
log "Gradle module: ${GRADLE_MODULE}"
log "Image        : ${FULL_IMAGE}"
echo ""

# ── Step 1: Build the fat JAR on the Mac ──────────────────────────────────────
log "Step 1: Running ./gradlew ${GRADLE_MODULE}:bootJar"
cd "${REPO_ROOT}"
./gradlew "${GRADLE_MODULE}:bootJar" \
  || fail "Gradle bootJar failed — fix build errors before retrying."
ok "Gradle bootJar succeeded"

# Find the JAR (exclude the -plain.jar that Spring Boot also emits)
JAR_FILE="$(find "${MODULE_ABS}/build/libs" -name "*.jar" ! -name "*-plain.jar" | head -1)"
if [ -z "${JAR_FILE}" ]; then
  fail "No executable JAR found under ${MODULE_ABS}/build/libs/ — did bootJar run?"
fi
log "JAR: ${JAR_FILE}"

# ── Step 2: Resolve Colima SSH address ────────────────────────────────────────
log "Step 2: Resolving Colima SSH address"

# colima status --json emits the SSH config including sshAddress / host+port.
# We parse host and port separately to construct a usable SCP/SSH target.
COLIMA_JSON="$(colima status --json 2>/dev/null)" \
  || fail "Could not reach Colima — is it running? Start with: colima start --arch x86_64"

COLIMA_HOST="$(echo "${COLIMA_JSON}" | jq -r '.driver.vmnetAddress // empty')"
COLIMA_SSH_CONFIG="$(colima ssh-config 2>/dev/null)"
# Parse Host and Port from the ssh-config block that matches the colima instance
SSH_HOST="$(echo "${COLIMA_SSH_CONFIG}" | awk '/^Host colima$/{found=1} found && /HostName/{print $2; exit}')"
SSH_PORT="$(echo "${COLIMA_SSH_CONFIG}" | awk '/^Host colima$/{found=1} found && /Port/{print $2; exit}')"
SSH_USER="$(echo "${COLIMA_SSH_CONFIG}" | awk '/^Host colima$/{found=1} found && /User/{print $2; exit}')"
SSH_KEY="$(echo "${COLIMA_SSH_CONFIG}" | awk '/^Host colima$/{found=1} found && /IdentityFile/{print $2; exit}')"

if [ -z "${SSH_HOST}" ] || [ -z "${SSH_PORT}" ]; then
  fail "Could not parse Colima SSH config — is Colima running with --arch x86_64?"
fi

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p ${SSH_PORT} -i ${SSH_KEY}"
SCP_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P ${SSH_PORT} -i ${SSH_KEY}"

ok "Colima SSH: ${SSH_USER}@${SSH_HOST}:${SSH_PORT}"

# ── Step 3: Verify Colima is linux/amd64 ──────────────────────────────────────
log "Step 3: Verifying Colima architecture"
COLIMA_ARCH="$(ssh ${SSH_OPTS} "${SSH_USER}@${SSH_HOST}" uname -m 2>/dev/null)" \
  || fail "SSH into Colima failed — check that Colima is running."
if [ "${COLIMA_ARCH}" != "x86_64" ]; then
  fail "Colima is running as '${COLIMA_ARCH}', not x86_64. Restart with: colima start --arch x86_64"
fi
ok "Colima architecture: ${COLIMA_ARCH}"

# ── Step 4: Copy JAR + Dockerfile into Colima ─────────────────────────────────
log "Step 4: Copying JAR and Dockerfile into Colima"

# Use a deterministic temp dir so the script is idempotent (safe to run twice)
COLIMA_BUILD_DIR="/tmp/reboot-build/${IMAGE_NAME}"
ssh ${SSH_OPTS} "${SSH_USER}@${SSH_HOST}" "mkdir -p ${COLIMA_BUILD_DIR}/build/libs"

JAR_FILENAME="$(basename "${JAR_FILE}")"
scp ${SCP_OPTS} "${JAR_FILE}"    "${SSH_USER}@${SSH_HOST}:${COLIMA_BUILD_DIR}/build/libs/${JAR_FILENAME}"
scp ${SCP_OPTS} "${DOCKERFILE}"  "${SSH_USER}@${SSH_HOST}:${COLIMA_BUILD_DIR}/Dockerfile"
ok "Files copied to Colima:${COLIMA_BUILD_DIR}"

# ── Step 5: Build and push inside Colima ──────────────────────────────────────
log "Step 5: Building linux/amd64 image inside Colima and pushing to ${FULL_IMAGE}"

# The Dockerfile uses COPY build/libs/*.jar — we rename our JAR to match the
# Dockerfile's COPY instruction (the image name without registry/tag).
# If the Dockerfile uses a glob, the rename is not strictly required, but
# keeping the filename predictable makes debugging easier.
ssh ${SSH_OPTS} "${SSH_USER}@${SSH_HOST}" bash -s <<EOF
  set -euo pipefail
  cd "${COLIMA_BUILD_DIR}"

  # Ensure buildx builder exists (idempotent: --use is a no-op if already selected)
  docker buildx inspect reboot-builder >/dev/null 2>&1 \
    || docker buildx create --name reboot-builder --use

  docker buildx use reboot-builder

  docker buildx build \
    --platform linux/amd64 \
    --tag "${FULL_IMAGE}" \
    --push \
    --output type=registry,registry.insecure=true \
    .
EOF

ok "Image pushed: ${FULL_IMAGE}"

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
log "Build and push complete."
log "To deploy: kubectl rollout restart deployment/${IMAGE_NAME} -n reboot-patterns"
log "           kubectl rollout status  deployment/${IMAGE_NAME} -n reboot-patterns --timeout=90s"
