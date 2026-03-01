# Handoff

## Task

- ID: T-20260301-tier-markers-and-change-control
- Owner: codex

## Summary

- Replaced canonical tier markers in `AGENTS.md` from `@tier` to safe `tier` syntax.
- Updated tier extraction scripts to support both `<!-- tier:x -->` and legacy `<!-- @tier:x -->`.
- Added `change-control` gate scripts for Windows/Linux to block out-of-scope changes and require docs/checklist/handoff evidence for functional edits.
- Integrated change-control gate into security review gate.
- Added scope template and active scope file.

## Files Touched

- AGENTS.md
- AGENTS-hot.md
- AGENTS-warm.md
- AGENTS-cold.md
- AGENTS-hot-warm.md
- scripts/extract-agents-tier.ps1
- scripts/extract-agents-tier.sh
- scripts/change-control-gate.ps1
- scripts/change-control-gate.sh
- scripts/security-review-gate.ps1
- scripts/security-review-gate.sh
- scripts/validate-review-report.ps1
- scripts/validate-review-report.sh
- coordination/change-scope.txt
- coordination/approval-overrides.json
- coordination/templates/change-scope.txt
- coordination/templates/review-report.md
- coordination/templates/approval-overrides.json
- coordination/reviews/T-20260301-tier-markers-and-change-control.md
- coordination/PLAN-TASK-PROTOCOL.md
- policy/security-review-gate.md
- README.md
- coordination/tasks.jsonl

## Verification

- `pwsh -NoProfile -File .\scripts\extract-agents-tier.ps1 -Check` -> passed after regeneration.
- `pwsh -NoProfile -File .\scripts\validate-parity.ps1` -> passed.
- `pwsh -NoProfile -File .\scripts\validate-review-report.ps1` -> passed.
- `pwsh -NoProfile -File .\scripts\change-control-gate.ps1` -> passed.
- `pwsh -NoProfile -File .\scripts\security-review-gate.ps1` -> passed (WARN: bash runtime limitation in this sandbox).

## Risks / Follow-ups

- Change-control gate is strict by default and requires maintaining `coordination/change-scope.txt` for each non-trivial task.
- Existing-test and architecture modifications are blocked by default; use explicit user-approved `coordination/approval-overrides.json` only when necessary.

## Commit Message

feat(policy): add strict change-control gate and normalize tier marker syntax
