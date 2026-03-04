# Handoff

## Task

- ID: T-20260304-gitcode-skills
- Owner: codex

## Summary

- Evaluated useful transferable practices from `obra/superpowers` and documented outcome in `.scratchpad/research.md`.
- Added `gitcode-pr-issue` skill for GitCode issue/PR creation using existing `gitee_util` automation.
- Added `gitcode-pr-review` skill for PR URL review with local checkout/diff evidence.
- Added eval coverage for both skills and updated `skills/README.md`.

## Files Touched

- .scratchpad/research.md
- .scratchpad/plan.md
- skills/gitcode-pr-issue/SKILL.md
- skills/gitcode-pr-review/SKILL.md
- skills/README.md
- evals/skills/cases/gitcode-pr-issue.md
- evals/skills/cases/gitcode-pr-review.md
- coordination/cycle-contract.json
- coordination/reviews/T-20260304-gitcode-skills.md
- coordination/tasks.jsonl
- coordination/state/codex.md

## Verification

- `pwsh -NoProfile -File .\scripts\validate-skills.ps1` -> pass.

## Risks / Follow-ups

- Add scripted integration smoke check against `gitee_util` CLI in a future task if end-to-end execution coverage is required.

## Commit Message

feat(skills): add gitcode issue-pr and pr-review skills with eval coverage

