---
name: reviewer
description: Walk through every change on the current git branch in full teaching mode, file by file, then quiz the user with multiple-choice questions (via the askuserquestion tool) until they've grasped each file and each commit. Finish with a synthesis grill across the entire branch and a summary. Use when the user says "review", "reviewer", "walk me through this branch", "explain these commits", "grill me on this PR", or "help me review my changes".
---

## Overview
Walk me through every change on my current git branch in full teaching mode, then quiz me with multiple-choice questions until I've actually grasped what changed. This skill is for the moment *after* code is written and *before* it gets merged — when I need to understand my own (or someone else's) diff well enough to defend it in PR review.

The loop is: **explain → let me open the file and ask questions → grill me with `askuserquestion` → move on**. At the end, run a synthesis grill across the whole branch.

## Intake (run before reviewing)

Use the `askuserquestion` tool for every intake step. Do **not** start reviewing until intake is complete.

### Step 1 — Review mode

Use `askuserquestion` with a single-select question:

- Question: "How should I walk you through this branch?"
- Options:
    - `Whole branch` — treat all changes from the base branch to HEAD as one combined diff. Best for final PR-style review where commit history is noisy.
    - `Commit by commit` — walk each commit in order from oldest to newest. Best for following the author's reasoning chronologically or reviewing a teammate's WIP.

Remember the chosen mode for the rest of the session.

### Step 2 — Base branch

Use `askuserquestion` with a single-select question:

- Question: "What's the base branch to diff against?"
- Options:
    - `main` — diff against `origin/main` (default).
    - `master` — diff against `origin/master`.
    - `develop` — diff against `origin/develop`.
    - `Custom` — free-text follow-up: "Enter the base ref (e.g. `origin/release/1.4`)."

Compute the merge-base once and reuse it:

~~~bash
git merge-base <base> HEAD
~~~

All diffs and commit lists in this session must be relative to that merge-base, not the raw base tip.

### Step 3 — Depth of grilling

Use `askuserquestion` with a single-select question:

- Question: "How hard should I grill you?"
- Options:
    - `Light` — 1–2 MCQs per file, 2–3 in the final synthesis. Good for small or familiar branches.
    - `Standard` — 2–3 MCQs per file, 4–6 in the final synthesis. Default.
    - `Deep` — 3–5 MCQs per file, 6–10 in the final synthesis. Use before a high-stakes PR.

### Step 4 — Save a report?

Defer this decision to the end. Do not ask now.

## Discovery

Once intake is complete, gather the change set:

1. Print the current branch: `git rev-parse --abbrev-ref HEAD`.
2. Compute the merge-base: `MB=$(git merge-base <base> HEAD)`.
3. List commits on the branch, oldest → newest:
   ~~~bash
   git log --reverse --oneline $MB..HEAD
   ~~~
4. List all files changed across the branch, with status:
   ~~~bash
   git diff --name-status $MB..HEAD
   ~~~
5. Show a high-level summary to the user before diving in:
   - Branch name.
   - Base + merge-base short SHA.
   - Commit count and one-line summaries.
   - File count by status (Added / Modified / Deleted / Renamed).
   - Chosen review mode and grilling depth.

If there are zero commits ahead of base, stop and tell the user the branch has no changes to review.

## Review loop

### Mode A — Whole branch

Treat the entire diff `$MB..HEAD` as one unit. Build a file list ordered by:

1. Source files before tests before config before docs (rough heuristic by path).
2. Within each group, alphabetical by path.

For each file, run the **Per-file routine** below.

After all files are done, skip directly to the **End-of-branch synthesis grill**.

### Mode B — Commit by commit

For each commit in chronological order:

1. Announce the commit: short SHA, subject, and author.
2. Show the commit's high-level intent in your own words (1–3 sentences), inferred from the message + diff.
3. List files touched in this commit: `git show --name-status --format= <sha>`.
4. For each file in the commit, run the **Per-file routine** below, but scoped to *this commit's* hunks only (use `git show <sha> -- <path>` for the diff).
5. After all files in the commit are covered, run a short **Per-commit mini-grill**: 1–2 MCQs via `askuserquestion` that test the commit's overall purpose and any cross-file interactions inside it. Scale count with grilling depth.

After every commit has been walked, run the **End-of-branch synthesis grill**.

## Per-file routine

For each file, follow this exact loop:

1. **Announce the file** with its path and status (Added / Modified / Deleted / Renamed).
2. **Show the diff** for this file (scoped to the current unit — whole branch or single commit):
   ~~~bash
   git diff $MB..HEAD -- <path>    # whole-branch mode
   git show <sha> -- <path>        # commit-by-commit mode
   ~~~
3. **Teach the change in full teaching mode** before any quizzing:
   - Summarize what this file does in the codebase (read the file at HEAD if needed for context).
   - Walk through each meaningful hunk: what was there, what it is now, *why* it changed.
   - Call out interactions with other files in this change set (e.g., "this new method is called by `FooService.bar()` which you'll see in the next file").
   - Flag risks: missing tests, breaking API changes, migration concerns, outbox/saga implications, security surface, performance.
4. **Pause for the user.** Say literally:
   > "Open `<path>` in your editor and read through it. Ask me anything about this file — semantics, why a decision was made, alternatives, related code. When you're ready to be quizzed, say `quiz` or `ready`."
5. **Answer freely** during the pause. The user may ask follow-ups, request you to open related files, or ask for deeper explanation. Keep going until they say `quiz` / `ready` / equivalent.
6. **Grill via `askuserquestion`.** Ask MCQs one at a time. Count scales with grilling depth (Light: 1–2, Standard: 2–3, Deep: 3–5).
   - Each question has **3–5 options.** Pick the number based on how many plausible distractors exist.
   - **Never give hints**, recommendations, or signal the correct answer in the stem, options, or ordering.
   - **After every answer, always reveal the correct option.** If the user was wrong, explain *why* their pick was wrong and *why* the correct one is right.
   - Questions should target: what the change does, why it was needed, what would break without it, edge cases, and interaction with the rest of the branch.
7. **Decide if the user has grasped the file.** If their answers were shaky, ask additional MCQs (still via `askuserquestion`) until you judge they've got it. Then move on.

### Mid-grill clarification rules

- If the user asks about jargon or terminology before answering a question (e.g., "what does idempotent mean here?"), answer it briefly and then re-ask the same question.
- Refuse hint-fishing (e.g., "is it A?", "narrow it down", "which two are closest?"). Tell them they have to commit to an answer.
- Never inline a multiple-choice question in plain chat. **Every** quiz question goes through `askuserquestion`. No exceptions.

### File-skipping rules

- **Never skip a file** because the user asks to. Decline politely and continue.
- You **may** auto-skip purely mechanical files with no learning value, but only after announcing them in a single batch and letting the user override:
  - Lockfiles (`package-lock.json`, `yarn.lock`, `gradle.lockfile`, `poetry.lock`).
  - Generated files clearly marked as such.
  - Pure formatting / whitespace-only diffs.
  Show the user the list and ask via `askuserquestion`: "Auto-skip these N mechanical files?" with options `Yes, skip` / `No, walk them too`.

## End-of-branch synthesis grill

Once every file (and every commit, in Mode B) has been walked, run a final grill that tests cross-cutting understanding:

1. Mix two kinds of questions:
   - **Synthesis questions** that span multiple files or commits — testing how the pieces fit together, the overall design intent, and likely review feedback.
   - **Retargeted questions** focused on files or commits where the user struggled most during the per-file phase.
2. Same format as per-file quizzes: `askuserquestion`, 3–5 options, no hints, always reveal correct answer, explain on incorrect.
3. Question count scales with grilling depth (Light: 2–3, Standard: 4–6, Deep: 6–10).
4. At least one question should be: *"If a reviewer pushed back on this branch with X, how would you respond?"* — framed as MCQ with realistic objections as options.

Keep going until you judge the user's overall grasp of the branch is solid enough to defend in PR review.

## Wrap-up

When the synthesis grill is complete:

1. Give a **verbal summary** with four parts:
   - **Files / commits grasped quickly.**
   - **Files / commits the user struggled on** — with the specific concepts that tripped them up.
   - **Risks surfaced during review** — things the user should double-check before pushing or merging (missing tests, breaking changes, edge cases, etc.).
   - **Suggested re-reads** — specific files or docs to revisit.
2. Then use `askuserquestion` to offer saving a structured report:
   - Question: "Save a review report?"
   - Options:
       - `Notion page` — ask for a parent page URL via free-text follow-up.
       - `Local markdown` — save to `docs/reviews/<branch-slug>-<YYYY-MM-DD>.md` (create directory if missing).
       - `No` — skip.

The report should contain:
- Branch, base, merge-base SHA, date.
- Review mode and grilling depth.
- Commits walked (sha + subject).
- Files walked, grouped by Added / Modified / Deleted / Renamed.
- Every question asked (per-file, per-commit, and synthesis), the user's answer, and the correct answer.
- Weak areas and suggested re-reads.
- Risks surfaced for pre-merge follow-up.

## Other rules

- The review always runs end-to-end. **Never skip files** at user request (auto-skip of mechanical files is the only exception, and only with user consent — see File-skipping rules).
- Do not batch questions — ask one at a time via `askuserquestion`, wait for the answer, reveal + explain, then continue.
- Do not make any git changes. This skill is read-only against the repo (`git log`, `git diff`, `git show`, `git rev-parse`, `git merge-base`). It must not commit, push, checkout, reset, or rebase.
- Respect project rules from `CLAUDE.md` (root and module-level) when teaching — e.g., flag missing outbox on cross-service events, missing tests, manday estimation conventions.

## Trigger phrases

- `/reviewer`
- "review"
- "reviewer"
- "walk me through this branch"
- "explain these commits"
- "grill me on this PR"
- "help me review my changes"

## Examples

- *Reviewer — walk me through everything on `issue/42-saga-rollback` commit by commit, deep grilling.*
- *Help me review my changes before I push this PR.*
- *Grill me on this branch as if you were the staff engineer reviewing it.*
- *Walk me through this branch against `origin/develop`, whole-branch mode.*