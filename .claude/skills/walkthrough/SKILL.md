---
name: walkthrough
description: Walk through a markdown doc section by section in full teaching mode, then quiz the user with multiple-choice questions (via the askuserquestion tool) until they've grasped each section. Finish with a synthesis grill across the whole doc and a summary. Use when the user says "walkthrough", "walk me through", "teach me this doc", "study this with me", or "quiz me on this doc".
---

## Overview
Walk through a markdown doc section by section in full teaching mode, then quiz me with multiple-choice questions until I've grasped each section. End with a synthesis grill across the whole doc. Use when I want to deeply learn a doc and be tested on it.

## Skill definition
When this skill is invoked, start by asking me how I'd like to provide the doc:
1. **Notion URL** — I'll paste a link to a Notion page.
2. **Local file path** — I'll point to a markdown file in the repo (e.g., `docs/issues/UAM-123.md`).
3. **Paste in chat** — I'll paste the markdown directly into the conversation.

Once I've provided the doc, walk through it section by section. Treat **every heading level (H1, H2, H3, H4, ...) as its own section** — my docs use different heading depths, so do not assume a fixed boundary like H2-only.

For each section, follow this loop:
1. **Teach the section in full teaching mode** before any quizzing:
   - Paraphrase the key points in your own words.
   - Walk through a worked example.
   - Clarify any jargon or terminology.
   - Connect this section back to earlier sections of the doc.
2. **Quiz me using the `askuserquestion` tool.** Every quiz question — without exception — must go through `askuserquestion`. Never inline a multiple-choice question in plain chat.
3. Each question has **3–5 multiple-choice options.** Pick the number based on how many plausible distractors exist for that concept.
4. **Never give hints, recommendations, or signal the correct answer** in the question stem, option phrasing, or order. Do not mark, hint at, or lean toward the right option.
5. **After I answer, always reveal the correct answer.** If I got it wrong, explain *why* my answer was incorrect and *why* the correct one is right.
6. **Keep asking new questions** (still via `askuserquestion`) until you judge I've genuinely grasped the section. Then move to the next section.

Mid-quiz clarification rules:
- If I ask about jargon or terminology before answering a question (e.g., "what does idempotent mean here?"), answer it briefly and then re-ask the same question.
- Refuse hint-fishing (e.g., "is it A?", "narrow it down", "which two are closest?"). Tell me I have to commit to an answer.

After the entire doc is covered, run the **end-of-doc grill**:
1. Mix two kinds of questions:
   - **Synthesis questions** that span multiple sections, testing how concepts connect across the doc.
   - **Retargeted questions** focused on the sections where I struggled most during the per-section phase.
2. Same format as section quizzes: `askuserquestion`, 3–5 options, no hints, always reveal the correct answer, explain on incorrect.
3. Keep going until you judge my overall grasp of the doc is solid.

When the end-of-doc grill is complete:
1. Give a **verbal summary** with three parts:
   - Sections I grasped quickly.
   - Sections I struggled on.
   - Suggested re-reads.
2. Then **offer (yes/no) to save a structured report** containing: sections covered, every question asked, my answers, weak areas, and re-read suggestions. If yes, ask whether to save as a Notion page or a local markdown file.

Other rules:
- The walkthrough always runs end-to-end. **Never skip sections.** If I ask to skip a section, decline and continue the full walkthrough.
- Do not batch questions — ask one at a time via `askuserquestion`, wait for my answer, reveal + explain, then continue.

## Trigger phrases
- "walkthrough"
- "walk me through"
- "teach me this doc"
- "study this with me"
- "quiz me on this doc"

## Examples
- *Walkthrough this PRD on the Reboot-UAM Identity service.*
- *Walk me through `docs/issues/UAM-42.md`.*
- *Teach me this doc on saga orchestration vs choreography.*
- *Study this with me — it's the design doc for the notices service event schema.*
- *Quiz me on this doc once you're done explaining each section.*