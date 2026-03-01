# Handoff

## Task

- ID: T-20260301-significant-doc-sync-rule
- Owner: codex

## Summary

Added an enforceable documentation rule for significant logic changes: change-control gate now requires `README.md` update when requirements/behavior/capabilities enforcement logic changes (gate scripts, validators, install/deploy core, policy/profile rules, AGENTS layer, manifest wiring).

## Files Touched

- scripts/change-control-gate.ps1
- scripts/change-control-gate.sh
- policy/security-review-gate.md
- README.md
- coordination/change-scope.txt
- coordination/tasks.jsonl
- coordination/reviews/T-20260301-significant-doc-sync-rule.md

## Verification

- `pwsh -NoProfile -File scripts/change-control-gate.ps1` -> PASS
- `pwsh -NoProfile -File scripts/security-review-gate.ps1` -> PASS

## Risks / Follow-ups

- Bash runtime is not available in this sandbox, so `.sh` execution is validated in git-bash hook runtime.

## Delivery Contract
Commit pending user approval.

## Commit Message
feat(gates): require README sync for significant logic changes
