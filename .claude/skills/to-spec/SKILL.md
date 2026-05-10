---
name: spec
description: Generate a complete Spec document from a resolved /grill-me session. Produces a 3-part spec (Business / Technical / Issue-Ready Breakdown) saved to docs/specs/, with optional Notion publishing. Part 3 is structured for direct extraction by /to-issues. Use when the user wants to generate, create, or write the spec, or mentions /spec after a grill-me session.
---

# spec

## Overview
Generate a complete Spec document from a resolved `/grill-me` session. The spec is a one-shot artifact structured into **3 audience-driven parts**:
- **Part 1 — Business Spec** → for managers and business stakeholders (zero technical jargon)
- **Part 2 — Technical Assessment** → for developers and tech leads (architecture, estimates, risks)
- **Part 3 — Issue-Ready Breakdown** → structured for direct extraction by `/to-issues`

The primary output is a **local markdown file** in `docs/specs/`. Writing to Notion is **optional** — the skill asks at the end whether to publish to Notion.

## Skill definition
When this skill is invoked, generate a full Spec document and write it to `docs/specs/`.

Follow these rules:

### Prerequisites
- **Requires a prior `/grill-me` session** in the current conversation. If no grill-me conversation exists, instruct the user to run `/grill-me` first.
- **Soft guard on completeness** — before generating, review the grill-me conversation for coverage of: problem statement, scope, approach, dependencies, **module decomposition**.
    - If critical gaps exist, use `AskUserQuestion` with a single-select question:
        - Question: "The grill-me session didn't cover [X, Y]. The spec will have gaps in those areas. How do you want to proceed?"
        - Options:
            - `Continue` — generate the spec anyway, accepting the gaps.
            - `Back to /grill-me` — stop and resolve the gaps in another `/grill-me` round before specing.
    - If fewer than ~2 deep modules can be identified from the conversation, the decomposition is too shallow. Use `AskUserQuestion` with a single-select question:
        - Question: "Module decomposition looks shallow (only [N] deep modules identified). How do you want to proceed?"
        - Options:
            - `Continue` — proceed with the current modules.
            - `Back to /grill-me` — go back and grill the module boundaries deeper.

### Input
- **Grill-me conversation** — the primary input, already in the session context.
- **Codebase scan** (automatic) — always performed before generation.

### Codebase Scan (automatic, two-level)
1. **Structural scan** (always) — project tree, module names, `CLAUDE.md`, build files (`build.gradle`, `pom.xml`), `docker-compose.yml`, existing `docs/` folder.
2. **Contextual scan** (smart) — if the grill-me conversation references specific services or components that already exist in the codebase, read their key files (entity classes, API controllers, schema migrations) to ground the spec in reality.

### Output
1. **Write to local markdown** — generate the full spec (all 3 parts) as a single `.md` file at `docs/specs/spec-[feature-name].md` (kebab-case, e.g. `spec-reboot-uam.md`). Create the `docs/specs/` directory if it doesn't exist.
2. **Confirm the file is written** — print the file path and a brief summary.
3. **Ask about Notion** — after the file is saved, use `AskUserQuestion` with a single-select question:
    - Question: "Want me to publish this spec to a Notion page?"
    - Options:
        - `Yes` — follow up with a free-text `AskUserQuestion`: "Paste the Notion page URL where the spec should be published." Once provided, validate the page via MCP, then overwrite the page body with the spec content. Set the page title to `SPEC — [Feature Name]`.
        - `No` — done. The local file is the deliverable.

### Notion Integration (optional)
1. **Only triggered when the user says yes** — never write to Notion automatically.
2. **Validate the Notion page** — attempt to read the Notion page via MCP before writing. If it fails, warn: *"Can't access that Notion page. Check the URL and MCP connection. The spec is saved locally at `docs/specs/[filename].md`."*
3. **Full overwrite** — replace the entire Notion page body with the generated spec. The page title should be set to `SPEC — [Feature Name]`.

### Generation Mode
- **One-shot** — generate the entire spec in a single pass. No pausing for section-by-section review. All decisions were already resolved during `/grill-me`.

### Post-Generation Summary
After writing the markdown file, print a brief summary in the session:
- ✅ Spec written to `docs/specs/[filename].md`
- 📋 Status: **Draft** | Version: **1.0**
- Total mandays: X
- Number of tasks: Y
- Number of issues ready for `/to-issues`: Z
- 🧩 Modules identified: N (new: A, B; modified: C) — e.g., AuthTokenService, UserRepository, OutboxPublisher
- Top risks: A, B, C
- 🧩 Module check — use `AskUserQuestion` with a multi-select question:
    - Question: "Do these modules match your expectations? Select any you want flagged for isolated behavioral tests first."
    - Options: one entry per module identified, plus an `All look good` option to skip flagging.
- 📄 Notion publish — trigger the `AskUserQuestion` defined in Output step 3.

## Estimation Convention
> **1 manday = 1 hour** (~2 sessions × 30 minutes)

All estimates in the Technical Assessment use this unit. The spec must include this definition (as a callout block) at the top of Part 2.

## Cross-Reference Convention
> **User Story IDs** — every User Story is numbered (US-1, US-2, ...). Parts 2 and 3 reference these IDs so readers can trace any task or issue back to its business justification without duplicating the story text.

## Formatting Guidelines
- Use **dividers** (`---`) between major parts and sections to give the document breathing room.
- Use **callout blocks** for key conventions (estimation unit, cross-reference legend).
- Use **toggle headings** for large reference sections (e.g., task groups by slice) so the document is scannable.
- Use **Mermaid diagrams** — business flow in Part 1, architecture and sequence diagrams in Part 2.
- Group tasks by **vertical feature slice** — each slice delivers a working end-to-end behavior. Never group by service/component or as one flat table.

## Status Metadata Convention
Every generated spec includes a YAML frontmatter block at the top of the markdown file for lifecycle tracking. When published to Notion, these fields map to page properties.

| Field | Type | Default | Description |
|---|---|---|---|
| **status** | Status | `Draft` | Lifecycle stage: `Draft`, `In Review`, `Approved`, `Superseded` |
| **version** | Text | `1.0` | Revision number, bumped manually on updates |
| **author** | Text | Session user | Who generated the spec |
| **created** | Date | Generation date | ISO date of initial generation |
| **last_updated** | Date | Generation date | ISO date of last revision |
| **feature** | Text | Kebab-case name | Feature identifier matching the filename |
| **grill_me_session** | Date | Session date | Date of the source `/grill-me` session for traceability |

- New specs always default to **`Draft`** status.
- Status transitions (`Draft` → `In Review` → `Approved`) are manual or handled by a future skill.
- When publishing to Notion as a database page, map these fields to matching database properties (Status → Status, Version → Text, Created → Date, etc.).

---

## Spec Template
The generated spec must follow this structure (rendered below as an indented code block so the inner fence does not conflict with the outer code fence):

    ---
    status: Draft
    version: 1.0
    author: [Author Name]
    created: [YYYY-MM-DD]
    last_updated: [YYYY-MM-DD]
    feature: [feature-name]
    grill_me_session: [YYYY-MM-DD]
    ---

    # Spec: [Feature Name]

    ---

    ## Part 1 — Business Spec
    // Audience: managers, business stakeholders. Zero technical jargon.

    ### Problem Statement
    // What problem exists and why it matters to the business.

    ### Scope
    // What the system will do.

    ### Out of Scope
    // What the system will NOT do in this phase.

    ### User Stories
    // Numbered: US-1, US-2, ... Grouped by role.
    // Written in "As a [role], I can [action] so that [benefit]" format.

    ### Acceptance Criteria
    // Mapped to User Story IDs (e.g., "AC for US-1, US-2: ...").

    ### High-Level Flow
    // Mermaid flowchart showing the business process.
    // Actors and actions only — no services, no Kafka, no databases.
    // Example: Clerk creates record → Submission sent to Approver → Approved/Rejected → Record updated.

    ### Alternatives & Trade-offs (Business-Level)
    // Simplified, non-technical. E.g., "We chose separate approval handling for auditability."
    // No mention of specific technologies or patterns.

    ---

    ## Part 2 — Technical Assessment
    // Audience: developers, tech leads. Full technical depth.

    ### Architecture Diagram
    // Mermaid diagram: services, data stores, message flows.

    ### Workflow Diagrams
    // Mermaid sequence diagrams for primary workflows (e.g., saga happy path, auth flow).

    ### Key Technical Decisions
    // Patterns, technology choices, and rationale.
    // E.g., Outbox pattern, idempotent consumers, encryption strategy, RBAC approach.

    ### Module Decomposition
    // 💡 A deep module encapsulates significant functionality behind a simple,
    // stable interface. Prefer fewer, deeper modules over many shallow ones.
    // Each module below is a unit that can be developed and tested in isolation. [USE CALLOUT BLOCK]
    //
    // Columns: Module, Responsibility, Public Interface, New / Modified, Test Seam
    // Example rows:
    //   AuthTokenService  | Issue/validate/rotate JWTs | issue(userId), validate(token), rotate(refreshToken) | New      | Behavioral tests against interface
    //   UserRepository    | Persistence for user agg.  | findById, save, findByEmail                          | Modified | Testcontainers (MariaDB)
    //   OutboxPublisher   | Reliable event publishing  | publish(event)                                       | New      | Embedded Kafka
    //
    // Module dependency diagram (Mermaid flowchart): nodes are modules, edges are
    // dependencies, external systems (DB, Kafka) shown as cylinders/queues.
    // Modules referenced here are cross-referenced by every issue in Part 3 via
    // the "Modules touched" field, giving a story → slice → issue → module trace.

    ### Dependencies
    // Infrastructure and library dependencies.

    > ℹ️ 1 manday = 1 hour (~2 sessions × 30 min) [USE CALLOUT BLOCK]

    ### Task Breakdown
    // Grouped by **vertical feature slices** — not by service/component.
    // Each slice delivers a working, demoable, end-to-end behavior that cuts
    // through all services and layers needed (DB → service → API → events → tests).
    // Slices are ordered so each builds on the last.
    // Columns: #, Task, Complexity, Mandays, Risk, Covers (US-IDs)

    #### Slice 0: Test & Build Infrastructure (toggle heading)
    // Shared library, test harness (Testcontainers, embedded Kafka/Redis, base test
    // classes), build config. No business logic — enables TDD for all following slices.
    | # | Task | Complexity | Mandays | Risk | Covers |
    |---|------|-----------|---------|------|--------|
    | 1 | ...  | ...       | ...     | ...  | Foundation |
    // Subtotal: X mandays

    #### Slice N: [Feature Slice Name] (toggle heading)
    // Each slice cuts vertically: migrations → entities → services → controllers →
    // Kafka producers/consumers → tests — across whichever services the feature touches.
    | # | Task | Complexity | Mandays | Risk | Covers |
    |---|------|-----------|---------|------|--------|
    | 1 | ...  | ...       | ...     | ...  | US-1, US-3 |
    // Subtotal: X mandays

    ### Total Estimate & Critical Path
    // Sum of all slices. Critical path is slice-sequential: Slice 0 → 1 → 2 → ...
    // Each slice delivers a working increment. Timeline feasibility.

    ### Risk Assessment
    #### High Risks
    #### Medium Risks
    #### Mitigation Strategies

    ---

    ## Part 3 — Issue-Ready Breakdown
    // Audience: /to-issues skill. Each entry is a self-contained work item.
    // Grouped by **vertical feature slices** — each slice delivers a working, testable,
    // end-to-end behavior. Issues within a slice cut through all services/layers needed.
    //
    // **TDD framing (Matt Pocock / tracer bullet):**
    // - Each issue defines the PUBLIC INTERFACE and the BEHAVIORS to verify through it.
    // - Do NOT pre-specify test class names or bulk-list tests before implementation.
    //   That is horizontal slicing — the explicit anti-pattern.
    // - During /build, use a tracer bullet: ONE test → ONE implementation → repeat.
    // - Tests must verify observable behavior through public APIs only.
    //   Never assert on internal state (DB rows, Redis keys, @Version columns, outbox tables).
    //   If you rename an internal function and a test breaks, that test is testing implementation.
    //
    // **Contract testing:** Any issue that introduces a Kafka producer/consumer pair must
    // include a contract behavior: assert the event shape produced is consumable by the receiver.
    //
    // **Slice ordering:** Each slice builds on the previous. Slice 0 is always test/build
    // infrastructure. Subsequent slices deliver demoable features incrementally.
    //
    // **Self-validation checklist — run this before writing the file:**
    // For every issue in Part 3, verify:
    //   [ ] Has a clear "Public Interface" field (endpoint, Kafka topic, or method signature)
    //   [ ] Behaviors expressed as observable outcomes — "returns 200 with X", not "assert Y written to DB"
    //   [ ] No test class names pre-specified (no LoginServiceTest, LoginIT, etc.)
    //   [ ] No internal state in behaviors (no outbox, @Version, Redis keys, DB row assertions)
    //   [ ] Behaviors ordered by priority — most important first
    //   [ ] Ask: "If I rewrote the internals completely, would these behaviors still pass?"
    //       If NO → the behavior is testing implementation, not behavior. Rewrite it.
    //   [ ] Contract behavior (if Kafka): "event produced by X is deserializable by Y with fields A, B, C"

    ### Slice 0: Test & Build Infrastructure (toggle heading)
    // Shared library, test harness (Testcontainers, embedded Kafka/Redis, base test
    // classes), build config, CI pipeline. No business logic — enables TDD for all
    // following slices.

    #### ISSUE-1: [Infrastructure Task Title]
    - **Description:** What this task delivers.
    - **User Stories:** Foundation for all US
    - **Modules touched:** Foundation (shared test harness / build infra — pre-module) or specific shared modules if introduced here
    - **Acceptance Criteria:** Specific, testable conditions.
    - **Estimated Mandays:** X
    - **Dependencies:** None
    - **Risk:** Low / Medium / High

    ### Slice N: [Feature Slice Name] (toggle heading)
    // Brief: what this slice delivers end-to-end and what a working demo looks like
    // after completing this slice.

    #### ISSUE-N: [Task Title]
    - **Description:** What this task delivers (crosses all layers/services needed).
    - **User Stories:** US-1, US-3
    - **Modules touched:** [e.g., `AuthTokenService` (new), `UserRepository` (modified)] — must match modules listed in Part 2 § Module Decomposition
    - **Public Interface:** [The endpoint / Kafka topic / method signature that tests will exercise]
    - **Behaviors to verify (in priority order):**
      1. [Observable outcome via public interface — e.g., "valid credentials return 200 with access + refresh token"]
      2. [Next most important behavior — e.g., "invalid credentials return 401"]
      3. [Edge/failure case — e.g., "after N failed attempts, returns 423"]
      - **Contract:** [if Kafka event — "event produced by X is deserializable by Y with fields A, B, C"]
    - **Acceptance Criteria:** Specific, testable conditions for this task.
    - **Estimated Mandays:** X (includes test-first effort)
    - **Dependencies:** ISSUE-X (if blocked by another task)
    - **Risk:** Low / Medium / High + brief note if High

    #### ISSUE-N+1: [Task Title]
    // Same structure...

## Trigger phrases
- `/spec`
- "generate the spec"
- "create the spec"
- "write the spec"

## Examples
- `/spec` → generates to `docs/specs/`, then asks about Notion
- `Generate the spec` → same flow
- `Write the spec` → same flow