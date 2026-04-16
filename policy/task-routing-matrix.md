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

## Commit-Output Gate

`Commit Message` is allowed only when:

- the current task produced a real tracked repo diff;
- required verification passed;
- no known secret, scope, or failed-gate blockers remain;
- the change is genuinely ready for a normal commit.

If those conditions are not met, omit commit-output blocks in ordinary user-facing answers.
