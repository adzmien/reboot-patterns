---
name: grill-me
description: >
  Interview the user relentlessly about a Product Doc (PD) until every branch
  of the product decision tree is resolved. Produces a Grilling Context Dossier
  intended as input to the /to-spec skill. Use when the user wants to
  stress-test a PD, get grilled on a product definition, or mentions "grill me".
---

# grill-me

Interview me relentlessly about every aspect of this **Product Doc (PD)** until we reach a shared understanding. Walk down each branch of the product decision tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time.

If a question can be answered by exploring the codebase, explore the codebase instead.

This skill exists to **prepare context for `/to-spec`**. The final output (the Grilling Context Dossier) is meant to be handed to `/to-spec`, which will turn it into a technical SPEC.

## Intake (run before grilling)

Before starting the interview, gather context using the `AskUserQuestion` tool. Do **not** start grilling until all intake steps below are complete.

### Step 1 — Where is the PD?

Use `AskUserQuestion` with a single-select question:

- Question: "Where is the PD you want me to grill?"
- Options:
    - `Notion` — the PD lives in a Notion page.
    - `Inline` — the user will describe the PD directly in chat.

Then branch:

- If **Notion** → use `AskUserQuestion` (free-text) to ask: "Paste the Notion page URL of the PD." Once provided, fetch/read the page contents before continuing.
- If **Inline** → use `AskUserQuestion` (free-text) to ask: "Describe the PD inline (paste the full text)." Use that description as the source of truth.

### Step 2 — Should I scan the codebase?

Use `AskUserQuestion` with a single-select question:

- Question: "Should I scan the codebase as part of grilling?"
- Options:
    - `Yes` — explore the codebase to ground questions about feasibility, existing behavior, and constraints.
    - `No` — grill purely from the PD text.

### Step 3 — Where should the dossier be saved?

Use `AskUserQuestion` with a single-select question:

- Question: "Where should I save the Grilling Context Dossier?"
- Options:
    - `Default` — save to `docs/grilling/<slug>-dossier.md` (slug derived from the PD title, kebab-case).
    - `Custom path` — free-text follow-up: "Enter the relative path (from repo root) where the dossier should be written."
    - `Do not save` — only print the dossier in chat; do not write a file.

Remember the chosen path for the Output step. If the directory does not exist, create it before writing.

### Step 4 — Which projects? (only if Step 2 = Yes)

If the user chose **Yes** in Step 2:

1. List all top-level project directories under the current working directory (each immediate subfolder that looks like a project root — e.g. contains a package.json, pom.xml, build.gradle, Cargo.toml, pyproject.toml, go.mod, or .git).
2. Use `AskUserQuestion` with a multi-select question:
    - Question: "Which projects should I include while grilling?"
    - Options: one entry per detected project directory, plus an `All` option.
3. Limit codebase exploration to the selected projects for the rest of the session.

If the user chose **No** in Step 2, skip this step and grill directly from the PD text.

## Grilling loop

Once intake is complete:

1. Build a mental decision tree from the PD. Typical branches to walk:
    - Problem & users — who, what pain, why now.
    - Scope & non-goals — what's in, what's explicitly out.
    - User journeys & flows — happy paths, edge cases, failure modes.
    - Functional requirements — capabilities, inputs/outputs, rules.
    - Non-functional requirements — performance, security, compliance, observability.
    - Data & domain model — entities, ownership, lifecycles.
    - Integrations & dependencies — upstream/downstream systems, contracts.
    - Success metrics — how we know it worked.
    - Risks & assumptions.
2. Walk the tree depth-first. For each open question:
    - State the question clearly.
    - Give your recommended answer with a short rationale.
    - Wait for the user's response before moving on.
3. If a question can be answered by reading the codebase (and codebase scanning was enabled for at least one project), read the relevant files instead of asking.
4. Track resolved vs. open branches; do not move on while dependencies of the current branch are unresolved.
5. Stop when every branch is either resolved, explicitly deferred by the user, or marked out-of-scope.

## Output — Grilling Context Dossier (input for /to-spec)

When grilling ends, emit a single markdown document titled "Grilling Context Dossier" with the following sections. This is the artifact `/to-spec` will consume.

**Where to write it:**

- Write the dossier to the path chosen in intake Step 3.
    - Default: `docs/grilling/<slug>-dossier.md`, where `<slug>` is a kebab-case slug of the PD's one-line summary (e.g. `reboot-uam-microservices-foundation-dossier.md`).
    - Custom: use the path the user provided.
    - Do not save: skip file creation; only print the dossier in chat.
- Create parent directories if they do not exist.
- If a file already exists at the target path, ask before overwriting.
- After writing, print the absolute or repo-relative path of the file in chat so `/to-spec` can pick it up.

Dossier template:

```markdown
# Grilling Context Dossier

## 1. Source PD
- Location: <Notion URL | inline>
- One-line summary: <...>

## 2. Problem & Users
- Problem statement
- Primary users / personas
- Jobs-to-be-done

## 3. Scope
- In scope
- Out of scope (non-goals)

## 4. Decisions Made

| # | Decision | Rationale | Source (PD / grilling / codebase) |
|---|----------|-----------|-----------------------------------|

## 5. Functional Requirements
- Capability -> expected behavior

## 6. Non-Functional Requirements
- Performance, security, compliance, observability, etc.

## 7. Data & Domain Model
- Entities, ownership, lifecycle notes

## 8. Integrations & Dependencies
- Upstream / downstream systems and contracts

## 9. Open Questions / Deferred
- Items explicitly deferred by the user (with reason)

## 10. Risks & Assumptions
- Risks surfaced
- Assumptions taken

## 11. Codebase Findings (if scanned)
- Project: <name>
    - Relevant files / modules
    - Constraints discovered

## 12. Handoff Note for /to-spec
- Recommended SPEC scope
- Suggested service / module boundaries
- Anything /to-spec should treat as a hard constraint
```

After emitting the dossier, tell the user:

> "Dossier ready at `<path>`. Run `/to-spec` next — point it at this file and it will draft the technical SPEC."