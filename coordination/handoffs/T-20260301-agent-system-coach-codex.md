# Handoff

## Task

- ID: T-20260301-agent-system-coach
- Owner: codex

## Summary

- Added a new coaching skill (`agent-system-coach`) for training developers on agent workflow, verification, and review discipline.
- Added matching slash command and helper agent definition.
- Added eval coverage and updated skills/docs inventory.

## Files Touched

- skills/agent-system-coach/SKILL.md
- commands/agent-system-coach.md
- .claude/agents/agent-system-coach.md
- evals/skills/cases/agent-system-coach.md
- skills/README.md
- README.md
- coordination/tasks.jsonl
- coordination/reviews/T-20260301-agent-system-coach.md

## Verification

- `pwsh -NoProfile -File .\scripts\validate-skills.ps1` -> pass.
- `pwsh -NoProfile -File .\scripts\validate-parity.ps1` -> pass.
- `pwsh -NoProfile -File .\scripts\security-review-gate.ps1` -> pass (with environment WARN for bash runtime in this sandbox).

## Risks / Follow-ups

- If external best-practice refresh is requested, apply only after explicit approval and rerun full gate suite.

## Commit Message

feat(training): add agent-system coach skill and helper agent with verification/review workflow
