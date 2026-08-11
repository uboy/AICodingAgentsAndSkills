# Task Routing Matrix

Use `policy/task-routing-matrix.json` as the compact routing source of truth.

## Core Rules

1. First classify the task by:
   - profile
   - size
2. Answer in the user's language.
3. Load only the skills and agents relevant to the selected profile.
4. Show repo/commit output only when the commit-output gate passes.

## Profiles

- `repo_change`: tracked repository edits
- `repo_read`: read-only repository analysis and review
- `content_task`: homework, transcript, rewriting, and other content-first work
- `general`: policy/process questions and lightweight discussion

## Content Task Academic Routing

When the active task is academic/content-first:

- Use `lecture-transcript` for raw lecture transcripts, ASR output, and rough lecture notes.
- Use `homework-management` for broader assignment support from provided materials.
- Use `case-analyzer` for case packets, scenario reasoning, options, trade-offs, and evidence gaps.
- Recommend `scripts/study-materials-prep.py` before skill execution when the source set is large, mixed-format, archive-based, or OCR-heavy.
- Treat prep as an agent-launched ingestion step: after running it, review `index.json`, `README.md`, and any `review_needed` entries before treating the pack as trusted.
- Keep `originals/` available as fallback when conversion is weak and prefer merged packs or non-duplicate files for first-pass context loading.
- Accept raw input directly when the user already provides a small, structured source set or curated excerpts.

## Execution Brief And Refresh

Before delegation or multi-step execution:

- refine the raw request into an execution brief
- include objective, output, constraints, sources, prep recommendation, verification, and chunking requirement
- refresh the brief after each verified chunk, scope change, or blocker
- default code work to small isolated verified chunks instead of broad monolithic patches

## Commit-Output Gate

`Commit Message` is allowed only when:

- the current task produced a real tracked repo diff;
- required verification passed;
- no known secret, scope, or failed-gate blockers remain;
- the change is genuinely ready for a normal commit.

If those conditions are not met, omit commit-output blocks in ordinary user-facing answers.
