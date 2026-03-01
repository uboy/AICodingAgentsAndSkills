# Handoff

## Task

- ID: T-20260301-commit-gate-stability
- Owner: codex

## Summary

Fixed OpenCode schema incompatibility by removing unsupported `statusLine`, added correction memory entries, and hardened change-control gates (PowerShell + bash) with a trivial config-only fast path plus `.agent-memory/*` allowance to reduce repeated commit-hook friction on small settings fixes.

## Files Touched

- opencode.json
- README.md
- .agent-memory/index.jsonl
- .agent-memory/entries/opencode/opencode-statusline-key-unsupported.json
- scripts/change-control-gate.ps1
- scripts/change-control-gate.sh
- coordination/change-scope.txt
- coordination/tasks.jsonl
- coordination/reviews/T-20260301-commit-gate-stability.md

## Verification

- `pwsh -NoProfile -File scripts/change-control-gate.ps1` -> PASS
- `pwsh -NoProfile -File scripts/security-review-gate.ps1` -> PASS
- `Get-Content opencode.json -Raw | ConvertFrom-Json | Out-Null` -> PASS

## Risks / Follow-ups

- Bash runtime is not available in this sandbox, so `.sh` execution was validated by parity and is expected to run in your git-bash hook environment.

## Delivery Contract
Commit pending user approval.

## Commit Message
fix(gates): support trivial config-only changes and remove invalid OpenCode statusLine
