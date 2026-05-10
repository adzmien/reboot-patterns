---
name: to-issues
description: Break a plan, spec, or PRD into independently-grabbable issues on the project issue tracker using tracer-bullet vertical slices. Tuned to consume `/spec` Part 3 output directly.
---

## Overview
Break a plan, spec, or PRD into independently-grabbable issues in `docs/issues/` using tracer-bullet vertical slices. Tuned to consume `/spec` Part 3 output directly.

## Skill definition
When this skill is invoked, follow the process below to publish issue markdown files to `docs/issues/` and update `docs/issues/INDEX.md`.

---

### Step 0 — Select a spec
If invoked **without** referencing a specific spec file, issue, or plan:
1. Scan `docs/specs/` for files matching `spec-*.md`.
2. Read each file's YAML frontmatter and filter to specs where `status: approved`.
3. Present a numbered list of approved specs:
   > **Approved specs ready for issue breakdown:**
   > 1. `spec-reboot-uam.md` — Reboot UAM
   > 2. `spec-loan-origination.md` — Loan Origination Core
   >
   > Which spec should I break into issues?
4. Wait for the user to select one, then proceed to Step 1.

If no approved specs are found, inform the user:
> No specs with `status: approved` found in `docs/specs/`. Make sure your spec frontmatter includes `status: approved` before running `/to-issues`.

If the user **does** reference a specific spec file, issue, or plan directly, skip this step and proceed to Step 1.

---

### Step 1 — Gather context
If the user references a spec file (`docs/specs/spec-*.md`) or a Notion spec page (titled "SPEC — ..."):
1. Read **Part 3 — Issue-Ready Breakdown** as the primary input. Each `ISSUE-N` becomes one published issue.
2. Read **Part 2 — Technical Assessment** for architecture context, estimation convention (1 manday = 1 hour), and risk details. Use this to enrich issue descriptions when Part 3 is terse.
3. Read **Part 1 — Business Spec** for user story definitions (US-1, US-2, …) referenced in Part 3. Do not re-derive slices from Part 1.

If the user passes an issue reference or raw plan instead, work from conversation context. If the user passes an issue reference (issue number, URL, or path) as an argument, fetch it from the issue tracker and read its full body and comments.

---

### Step 2 — Explore the codebase
Always explore the codebase to understand the current state of the code, even if you have prior context. Issue titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

---

### Step 3 — Draft vertical slices
Break the plan into **tracer bullet** issues. Each issue is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

Slices may be 'HITL' or 'AFK'. HITL slices require human interaction, such as an architectural decision or a design review. AFK slices can be implemented and merged without human interaction. Prefer AFK over HITL where possible.

**Vertical slice rules:**
- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones

#### HITL/AFK Inference Rule
When the source is a `/spec` Part 3 output, infer the slice type:
- **HITL** if any of these signals are present:
  - Risk is **High** AND description mentions architectural decisions, external API contracts, security review, or stakeholder approval
  - Description explicitly requires a design decision not yet resolved
  - Acceptance criteria include "decide", "choose", "review with", or "sign-off"
- **AFK** — everything else (default)

If uncertain, suggest with justification and ask for confirmation:
> "ISSUE-N ([title]) — I'm leaning **HITL** because [reason, e.g. 'the acceptance criteria require choosing between X and Y which is an unresolved architectural decision']. Agree, or should this be AFK?"

#### Slice 0 Handling
Do NOT create a separate infrastructure-only slice (Slice 0). Each vertical slice is responsible for setting up any infrastructure, test harness, or build config it requires. This keeps slices self-contained and mirrors real incremental development.

If the source `/spec` contains a Slice 0, redistribute its tasks into the slices that actually need them.

---

### Step 4 — Confirm before publishing
Do NOT quiz the user on granularity, dependencies, or slice merging. All decisions were resolved upstream.

Print a brief confirmation summary:
> "Found N issues across M slices. Publishing in dependency order. Proceed?"

On **yes** → go to Step 5 (publish).
On **no** → ask what the user wants to change.

> **Spec field mapping:** The spec (Part 3) produces additional fields per issue (User Stories, Public Interface, Behaviors to verify, Estimate, Risk) that are NOT duplicated into the issue body. The issue template is intentionally lean. All detailed context is traceable via the Spec Reference link. A dev who needs estimate, risk, or TDD guidance opens the referenced spec.

---

### Step 5 — Publish issues to `docs/issues/`
For each approved slice, create a new issue markdown file in `docs/issues/` using the issue body template below. Update `docs/issues/INDEX.md` with the new entries (see **INDEX.md Format** below).

Publish issues in dependency order (blockers first) so you can reference real issue identifiers in the "Blocked by" field.

#### File naming
Use the format `<id>-<kebab-slug>.md` (e.g. `42-saga-rollback-on-payment-failure.md`):
- `<id>` is the tracker ID without the `#` prefix. No zero-padding.
- `<kebab-slug>` is derived from the title: lowercase, alphanumerics + hyphens only, collapse runs of hyphens, trim leading/trailing. No truncation, no stop-word removal.
- The filename is **immutable after publish**. The title may change later, but the filename and tracker ID do not.

#### Status line
Do NOT write a `Status:` line in newly-published issues. Status defaults to `open` when absent. The line is added later by downstream skills (e.g. `/pick-issue`) when transitioning to `in-progress` or `done`. Vocabulary: `open` / `in-progress` / `done`, optionally suffixed with an ISO date (e.g. `Status: in-progress 2026-05-04`).

---

## Issue Template

    ## Parent

    A reference to the parent issue on the issue tracker (if the source was an existing issue, otherwise omit this section).

    ## Spec Reference

    ISSUE-N from `docs/specs/spec-[feature-name].md` (if the source is a `/spec` output, otherwise omit this section).

    ## What to build

    A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation.

    ## Acceptance Criteria

    - [ ] Criterion 1
    - [ ] Criterion 2
    - [ ] Criterion 3

    ## Blocked by

    - #issue-number of blocking ticket (published in dependency order)

    Or "None — can start immediately" if no blockers.

---

## INDEX.md Format
`docs/issues/INDEX.md` is a single markdown file with one H1 and one table:

    # Issues Index

    | ID  | Title                              | Type | Status | Spec    | Blocked by | File                              |
    | --- | ---------------------------------- | ---- | ------ | ------- | ---------- | --------------------------------- |
    | #42 | Saga rollback on payment failure   | AFK  | open   | ISSUE-3 | —          | `42-saga-rollback.md`             |
    | #43 | Outbox dispatcher worker           | AFK  | open   | ISSUE-4 | —          | `43-outbox-dispatcher.md`         |

Column rules:
- **ID** — tracker ID with `#` prefix (e.g. `#42`).
- **Title** — plain text, mirrors the issue file's H1. Truncate to ~60 chars in the table only; the full title stays in the file.
- **Type** — `AFK` or `HITL`, inferred per Step 3.
- **Status** — `open` / `in-progress` / `done`. Always `open` for newly-published rows. This column is a **derived cache** of the body's `Status:` line; the body is the source of truth, and downstream skills (e.g. `/pick-issue`) self-heal the column on read.
- **Spec** — the `ISSUE-N` identifier from the source spec. Empty cell if the issue had no spec source.
- **Blocked by** — comma-separated tracker IDs (e.g. `#44, #51`), or `—` (em dash) if none.
- **File** — backtick-wrapped filename only, no `docs/issues/` prefix.

Append rows in dependency order (blockers first) so each row's `Blocked by` can reference real tracker IDs.

Do NOT add columns for Priority, Created date, or Parent — those live in the body or are available via git history.

## Numbering — ISSUE-N Cross-Reference
When the source is a `/spec` output, each published issue must include a "Spec Reference" section (as defined in the issue template) with the original `ISSUE-N` identifier from the spec.

For the "Blocked by" field, use **real tracker IDs** (e.g., #42), not `ISSUE-N` placeholders. This is why issues are published in dependency order — blockers get real IDs first, so downstream issues can reference them.

Example:

    ## Spec Reference
    ISSUE-3 from `docs/specs/spec-reboot-uam.md`

    ## Blocked by
    - #41 (ISSUE-2)

Do NOT close or modify any parent issue.

---

## Trigger phrases
- `/to-issues`
- "break this into issues"
- "create issues from this"
- "convert to issues"