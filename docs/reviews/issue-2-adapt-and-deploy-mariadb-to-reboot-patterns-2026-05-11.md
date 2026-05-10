# Review Report — issue/2-adapt-and-deploy-mariadb-to-reboot-patterns

- **Branch:** `issue/2-adapt-and-deploy-mariadb-to-reboot-patterns`
- **Base:** `main` / merge-base `c88bd9a`
- **Date:** 2026-05-11
- **Review mode:** Commit by commit
- **Grilling depth:** Deep (3–5 MCQs per file, 6–10 synthesis)

---

## Commits walked

- `0c00546` — chore(#2): adapt and deploy MariaDB to reboot-patterns
- `8d77ff9` — chore(#2): add changelog

---

## Files walked

### Added
- `infra/k8s/mariadb/02-configmap.yaml`
- `infra/k8s/mariadb/03-statefulset.yaml`
- `infra/k8s/mariadb/04-service.yaml`
- `docs/issues/changelogs/2-adapt-and-deploy-mariadb-to-reboot-patterns.md`

### Modified
- `docs/issues/2-adapt-and-deploy-mariadb-to-reboot-patterns.md`

### Deleted
None.

---

## Questions, answers, and outcomes

### `02-configmap.yaml` (Commit 1)

| # | Question | User answer | Correct? | Correct answer |
|---|---|---|---|---|
| 1 | What happens to init.sql on a StatefulSet pod restart (not fresh provisioning)? | init.sql is skipped entirely because the data directory already exists | ✅ | Same |
| 2 | Why is `'rebootuser'@'%'` necessary rather than `'rebootuser'@'localhost'`? | Spring Boot services run as pods with dynamic IPs that can't be predicted | ✅ | Same |
| 3 | Why does init.sql pre-create schemas instead of letting Flyway do it? | Flyway manages tables inside a schema but requires the schema to already exist | ✅ | Same |
| 4 | What happens if `FLUSH PRIVILEGES` is removed? | GRANTs are written to grant tables but in-memory cache may not reflect them until restart | ✅ | Same |
| 5 | Why keep `my.cnf` and `init.sql` in one ConfigMap instead of two? | Single ConfigMap is simpler and sufficient — both are owned by MariaDB with the same lifecycle | ✅ | Same |

**Score: 5/5**

---

### `03-statefulset.yaml` (Commit 1)

| # | Question | User answer | Correct? | Correct answer |
|---|---|---|---|---|
| 1 | What happens to the PVC `mariadb-data-mariadb-0` if you delete the StatefulSet entirely? | PVC is retained but becomes unbound, so data is lost when a new StatefulSet claims it | ❌ | PVC is retained and must be deleted separately — the data survives StatefulSet deletion |
| 2 | Why is `readOnly: true` appropriate for ConfigMap mounts but not the data mount? | MariaDB writes its data files and transaction logs to /var/lib/mysql at runtime | ✅ | Same |
| 3 | What is the consequence of no `readinessProbe`? | Pod is marked Ready as soon as the container process starts, so Spring Boot may connect before MariaDB is ready | ✅ | Same |
| 4 | What type of Service does a StatefulSet's `serviceName` require, and what does it provide? | A NodePort Service — so pods can be reached from outside the cluster | ❌ | A headless Service (clusterIP: None) — which creates per-pod DNS records like `mariadb-0.mariadb.reboot-patterns.svc.cluster.local` |
| 5 | What does `imagePullPolicy: IfNotPresent` mean when a new MariaDB version is released? | IfNotPresent checks the local image store by tag — pulls if not cached, skips if cached | ✅ | Same |

**Score: 3/5**

**Weak areas:** PVC lifecycle (PVCs are independent of StatefulSet lifecycle, must be deleted separately); headless service requirement for `serviceName` (provides per-pod DNS, not external access).

---

### `04-service.yaml` (Commit 1)

| # | Question | User answer | Correct? | Correct answer |
|---|---|---|---|---|
| 1 | Which JDBC URL is correct for in-cluster access? | `jdbc:mariadb://mariadb:3306/p3_outbox` | ✅ | Same |
| 2 | Where must the selector label `app: mariadb` appear? | On the pod template's metadata.labels inside the StatefulSet spec | ✅ | Same |
| 3 | What happens if port 30306 is already allocated to a different Service? | The apply fails with a validation error — NodePort is already in use | ✅ | Same |
| 4 | If the `nodePort: 30306` field is removed entirely from a `type: NodePort` Service, what happens? | The Service falls back to type: ClusterIP | ❌ | Kubernetes assigns a random available port from the NodePort range (30000–32767) |
| 5 | What feature is lost because `serviceName` points at a NodePort Service instead of a headless one? | PVC binding breaks — StatefulSets require a headless service to associate PVCs with pods | ❌ | Per-pod DNS records like `mariadb-0.mariadb.reboot-patterns.svc.cluster.local` are not created |

**Score: 3/5**

**Weak areas:** NodePort field omission (Kubernetes auto-assigns from range, doesn't downgrade type); headless service purpose (DNS records, not PVC binding).

---

### `docs/issues/2-adapt-and-deploy-mariadb-to-reboot-patterns.md` (Commit 1)

| # | Question | User answer | Correct? | Correct answer |
|---|---|---|---|---|
| 1 | What does a future `/pick-issue` run do if INDEX.md shows `in-progress` but body says `done`? | Rewrites INDEX.md to done and excludes from open list | ✅ | Same |
| 2 | What does checking the ACs (`- [x]`) actually assert? | That the Gradle build passed, confirming no compilation errors | ❌ | That the sub-agent ran `kubectl apply` and the live cluster confirmed each criterion |
| 3 | Who is supposed to flip status to `done`, and when? | The sub-agent flips it after all ACs pass in the cluster | ❌ | The user flips it manually, only after the PR is merged to main |
| 4 | What risk does the missing `01-secret.yaml` create for someone cloning the repo fresh? | The apply fails immediately — Kubernetes validates Secret references before creating the StatefulSet | ❌ | The StatefulSet and Service are created, but the MariaDB pod enters `CreateContainerConfigError` state because the Secret doesn't exist |

**Score: 1/4**

**Weak areas:** AC checkbox semantics (runtime verification, not build-time); `/pick-issue` workflow gates (user sets done post-merge, not the sub-agent); Kubernetes Secret admission behaviour (lazy evaluation, not eager validation).

---

### Commit 1 mini-grill

| # | Question | User answer | Correct? | Correct answer |
|---|---|---|---|---|
| 1 | Why does the numbering start at 02, with no 01 committed? | `01-secret.yaml` exists on disk and is gitignored — numbering reflects apply order including untracked files | ✅ | Same |
| 2 | Should K8s infra manifests live in a separate infra repo? | It's a pragmatic choice for a solo learning project | Partial ✅ | Co-location is an architectural choice: bash tests run `kubectl` against these manifests, making them part of the definition-of-done for each pattern |

---

### `docs/issues/changelogs/2-adapt-and-deploy-mariadb-to-reboot-patterns.md` (Commit 2)

| # | Question | User answer | Correct? | Correct answer |
|---|---|---|---|---|
| 1 | Why does `/pick-issue` recommend squash merge? | Makes it easier to revert the entire issue's changes with a single `git revert` | ✅ | Same |
| 2 | Is the missing `8d77ff9` in the Commits section an error? | No — the changelog was written before it was committed; structurally unavoidable | ✅ | Same |
| 3 | How should a reviewer treat the CREATE TABLE AC being verified on only 3/8 schemas? | Accept it — 3 schemas is representative sampling and sufficient for ✅ | ❌ | Reject or flag as ⚠️ — "each other schema" is unambiguous; the ✅ should be ⚠️ with a note that 5 schemas were not directly tested |
| 4 | Why is `kubectl create secret` a better recovery path than a placeholder `01-secret.yaml` in git? | A placeholder is dangerous — someone might apply it to a production cluster and overwrite real credentials | ✅ | Same |
| 5 | What does YAML validation NOT confirm that only a live `kubectl apply` would catch? | Image pullability | Partial ❌ | Both namespace existence AND API schema validation — image pullability is a third layer, not caught at apply time either |

**Score: 3/5**

**Weak areas:** AC sampling vs exhaustive verification (the criterion wording is the standard, not effort proportionality); YAML validation scope (kubectl apply catches schema + namespace, not image availability).

---

### Commit 2 mini-grill

| # | Question | User answer | Correct? | Correct answer |
|---|---|---|---|---|
| 1 | Why is the changelog a separate commit? | GitHub's squash-merge requires the last commit to be a doc commit | ❌ | The changelog must come after implementation commits because it references SHAs, files, and live verification results that don't exist until after the work is done |
| 2 | What is the changelog's ongoing value after merge? | Lets a future reader understand what was verified, deferred, and why, without reconstructing branch history | ✅ | Same |

---

### Synthesis grill

| # | Question | User answer | Correct? | Correct answer |
|---|---|---|---|---|
| 1 | What single manual step is needed to produce a Running pod after a full namespace rebuild from git? | Re-apply `01-secret.yaml` manually — it's gitignored and the StatefulSet references it via `secretKeyRef` | ✅ | Same |
| 2 | Real-world impact of `serviceName` pointing at a NodePort Service (1 replica, JDBC use case)? | None in practice — with replicas: 1, Spring Boot connects via ClusterIP name which works identically | ✅ | Same |
| 3 | Concrete consequence of the premature `Status: done` if the PR is abandoned? | Future `/pick-issue` run treats the issue as closed, even if the PR is reverted | ✅ | Same |
| 4 | How to respond to a reviewer who flags the missing readiness probe? | CLAUDE.md §12 justifies omitting it for beginner clarity | ❌ | Scope discipline: ISSUE-2 is a manifest adaptation task; the probe belongs in ISSUE-9 (apply-all.sh) or a follow-up issue |
| 5 | Is `chore(#2)` the correct commit prefix for infra work? | CLAUDE.md §6 is a suggestion, not enforced by tooling | ❌ | Correct — `pattern(p<N>-<pattern>)` applies only to pattern subproject work; `chore(#<id>)` is right for shared infra; `/generate-tests` reads this prefix |
| 6 | Single most important fix before pushing? | Update the changelog CREATE TABLE AC row from ✅ to ⚠️ | Partial — | Revert `Status: done` to `Status: in-progress` (higher stakes: corrupts the `/pick-issue` workflow state if the PR is abandoned) |

---

## Weak areas

- **PVC lifecycle** — PVCs created by `volumeClaimTemplates` are independent of the StatefulSet and survive its deletion. Must be deleted explicitly. Re-read: Kubernetes StatefulSet docs → "Stable Storage" section.
- **Headless service / `serviceName`** — `serviceName` requires a headless Service for per-pod DNS. The headless service is for DNS identity; PVC binding is handled by the StatefulSet controller separately.
- **`/pick-issue` workflow gates** — The user sets `done` post-merge, not the sub-agent. The orchestrator does not auto-flip it. `approve` triggers push; `done` is manual after merge.
- **AC verification semantics** — `- [x]` means runtime verification against the live cluster, not static analysis. Sampling (3/8 schemas) against a criterion that says "each other schema" is a gap that should be ⚠️, not ✅.
- **CLAUDE.md §6 commit convention** — The `pattern()` prefix is machine-read by `/generate-tests` to route bash test generation. It's a hard convention, not style. `chore(#<id>)` is the correct form for infra work.

## Suggested re-reads

- Kubernetes StatefulSet documentation — PVC lifecycle and governing service sections.
- [docs/issues/changelogs/2-adapt-and-deploy-mariadb-to-reboot-patterns.md](../issues/changelogs/2-adapt-and-deploy-mariadb-to-reboot-patterns.md) — re-read outstanding follow-ups.
- CLAUDE.md §6 — commit conventions, focusing on when `pattern()` applies vs `chore()`.

## Pre-merge risks

1. **`Status: done` is premature** — revert to `in-progress` in the issue body before pushing.
2. **Changelog CREATE TABLE AC** — change ✅ to ⚠️ and note only 3/8 schemas were directly tested.
3. **No readiness probe** — document as a follow-up for ISSUE-9 or a dedicated issue.
4. **No secret recovery documentation** — add a `kubectl create secret` one-liner to `infra/k8s/mariadb/README.md` or `infra/k8s/README.md`.
