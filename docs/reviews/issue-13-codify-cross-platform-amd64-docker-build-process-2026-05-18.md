# Review Report — issue/13-codify-cross-platform-amd64-docker-build-process

- **Branch:** `issue/13-codify-cross-platform-amd64-docker-build-process`
- **Base:** `origin/main`
- **Merge-base:** `0525f0d`
- **Date:** 2026-05-18
- **Review mode:** Whole branch
- **Grilling depth:** Deep

---

## Commits walked

| SHA | Subject |
|-----|---------|
| `85e8d34` | feat(#13): add cross-platform amd64 build-and-push script |
| `b5a1289` | chore(#13): add changelog |

---

## Files walked

### Added
- `scripts/build-and-push.sh`
- `docs/issues/changelogs/13-codify-cross-platform-amd64-docker-build-process.md`

### Modified (auto-skipped — mechanical status updates)
- `docs/issues/13-codify-cross-platform-amd64-docker-build-process.md`
- `docs/issues/INDEX.md`

---

## Quiz record

### scripts/build-and-push.sh (5 questions)

**Q1:** If `set -euo pipefail` were removed and `scp` silently failed, what would the script do next?
- User answered: Exit immediately with a non-zero status ❌
- Correct: Continue and attempt Step 5 with whatever is already on the Colima VM
- Explanation: `fail()` is opt-in; `set -e` is the automatic safety net. Without it, failed commands are silently ignored and execution continues.

**Q2:** What value does `GRADLE_MODULE` hold after the `tr '/' ':'` transformation for input `patterns/p3-outbox`?
- User answered: `:patterns:p3-outbox` ✅
- Explanation: `tr '/' ':'` replaces every `/` with `:`, and the outer `":"$(...)` prepends the required leading colon for Gradle multi-project syntax.

**Q3:** What happens if the `-plain.jar` exclusion is removed from the `find` command?
- User answered: Spring Boot refuses to start the plain JAR, so the K3s pod crashes with a ClassNotFoundException ❌
- Correct: `head -1` picks one of the two JARs non-deterministically; there's a 50% chance the plain JAR is used
- Explanation: The real danger is non-determinism from filesystem ordering. The failure mode if the plain JAR is picked is `no main manifest attribute`, not `ClassNotFoundException`.

**Q4:** Why is `registry.insecure=true` required in the `docker buildx build` command?
- User answered: The K3s registry at 100.66.8.44:30500 is HTTP-only (no TLS), and Docker refuses to push to a non-HTTPS registry without this flag ✅

**Q5:** What is the practical consequence of the dead `COLIMA_HOST` variable assigned with `jq`?
- User answered: Nothing — the dead variable has no runtime consequence because it is never referenced ❌
- Correct: The script silently requires `jq` to be installed on the Mac, even though `jq` contributes nothing to the actual build
- Explanation: The assignment command (`jq -r ...`) still executes even if the value is never used. If `jq` is absent, `set -e` exits the script with a confusing error about a missing binary.

---

### docs/issues/changelogs/13-... (4 questions)

**Q1:** What happens if the issue tracker is not configured to process the `Closes #13` trailer?
- User answered: The commit lands as written, but issue #13 stays open — someone must close it manually ✅

**Q2:** What is the purpose of the `Iterations used: 1 of 5` field?
- User answered: Whether the issue was harder or easier than the allocated estimate, to calibrate future estimates ✅

**Q3:** What would be the consequence of skipping the Acceptance Criteria section?
- User answered: The changelog would be missing the traceability link between what was promised in the issue and what was actually built ✅

**Q4:** Why is the `bootRun N/A` note worth including rather than omitting the Verification section?
- User answered: It signals that the omission was deliberate, not an oversight — a reviewer won't wonder if the author forgot to run the app ✅

---

### Synthesis grill (7 questions)

**Q1:** Why does the project separate the script commit and the changelog commit instead of squashing?
- User answered: Git best practice always requires documentation commits to be separate from code commits ❌
- Correct: CLAUDE.md §6 requires one logical change per commit; mixing concerns breaks `/generate-tests`
- Explanation: This is a project-specific rule, not a universal git convention. The `/generate-tests` skill reads a single commit's diff to derive test scenarios.

**Q2:** Why build the JAR on the Mac and only delegate the docker build to Colima?
- User answered: Gradle is not available inside the Colima VM ❌
- Correct: The Mac has the Gradle cache and daemon warm; only the docker build step requires amd64
- Explanation: The script header explicitly cites speed. Building in a cold Colima VM would also require installing the JDK there.

**Q3:** What is the practical implication of the hardcoded `REGISTRY` constant for a second developer?
- User answered: The script fails immediately because 100.66.8.44 is unreachable ❌
- Correct: The contributor must edit the constant and carry a permanent local diff that gets overwritten on every pull
- Explanation: The failure happens at Step 5 (push), not immediately. The real issue is workflow friction for a multi-developer setup.

**Q4:** Is the script truly idempotent?
- User answered: Yes, fully idempotent ❌
- Correct: Mostly — but stale JARs accumulate in the Colima build dir after a version bump, which can break the Dockerfile COPY glob
- Explanation: `scp` adds the new JAR but never deletes old ones. If the JAR filename changes between runs, both files coexist in `build/libs/`.

**Q5:** Why does Step 5 use `ssh ... bash -s <<EOF` (heredoc) rather than an inline quoted SSH argument?
- User answered: Heredoc tells SSH to run bash in interactive mode ❌
- Correct: Heredoc avoids shell escaping complexity for a multi-line command with multiple flags and quoted strings
- Explanation: `bash -s` is non-interactive. The heredoc lets you write the remote commands naturally without complex nested escaping.

**Q6:** How would you respond to a reviewer objecting to `StrictHostKeyChecking=no`?
- User answered: Acknowledge the risk; the blast radius is zero in a local setup, and the flags prevent the script from hanging when Colima assigns a new address ✅

**Q7:** Why was this tracked as a formal issue rather than a one-off commit?
- User answered: The build process is a shared operational dependency for all 8 patterns; formalising it creates a traceable decision record and the AC list proves it was tested ✅

---

## Weak areas

| Area | Concept that tripped up |
|------|------------------------|
| `set -euo pipefail` | `fail()` is opt-in; `set -e` is automatic — removing it allows silent failure and continuation |
| Plain JAR exclusion | `head -1` non-determinism; the failure mode is `no main manifest attribute`, not ClassNotFoundException |
| Dead `COLIMA_HOST` variable | A dead assignment still executes its RHS — the `jq` binary must be installed even though its output is never used |
| Script idempotency | Stale JAR accumulation after version bumps; `scp` appends, never cleans |
| Gradle build location rationale | Speed/cache advantage, not binary availability |
| Heredoc vs inline SSH | `bash -s` is non-interactive; heredoc is about escaping ergonomics |

---

## Pre-merge risks

1. **Remove dead `COLIMA_HOST`/`jq` block** (lines 84–85) — undocumented `jq` dependency with no payoff.
2. **Stale JAR cleanup** — add `rm -f ${COLIMA_BUILD_DIR}/build/libs/*.jar` before the SCP in Step 4 to prevent accumulation after version bumps.
3. **Hardcoded `REGISTRY`** — acceptable for single-developer use; document the override path for future contributors.
4. **`StrictHostKeyChecking=no` comment** — add a one-line inline comment explaining why it's intentional to prevent future "fix" PRs.

## Suggested re-reads

- [scripts/build-and-push.sh:84-85](../../../scripts/build-and-push.sh#L84-L85) — dead `jq` block; trace what happens if `jq` is absent
- [scripts/build-and-push.sh:108-118](../../../scripts/build-and-push.sh#L108-L118) — Step 4 SCP; think through Colima build dir state after two runs with different JAR filenames
