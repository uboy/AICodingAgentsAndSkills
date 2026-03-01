# Security Review Gate

This gate is mandatory for script/config/policy changes before completion.

## Required Command

Windows:

```powershell
pwsh -NoProfile -File .\scripts\security-review-gate.ps1
```

Linux/macOS:

```bash
bash ./scripts/security-review-gate.sh
```

## Gate Checks

1. Merge conflict markers in changed files.
2. High-confidence secret patterns in changed files.
3. Syntax sanity:
- PowerShell parser checks for changed `*.ps1`
- `bash -n` checks for changed `*.sh` (if bash exists)
4. Skill schema validation if `skills/` changed.
5. Fast integrity runner:
- `scripts/run-integrity-fast.ps1` (Windows)
- `scripts/run-integrity-fast.sh` (Linux/macOS)
- includes cross-OS script parity, cross-system adapter checks, quick config/structure checks.
6. Change-control gate:
- `scripts/change-control-gate.ps1` (Windows)
- `scripts/change-control-gate.sh` (Linux/macOS)
- blocks out-of-scope file changes based on `coordination/change-scope.txt`
- requires checklist/handoff evidence for functional changes (`coordination/tasks.jsonl`, `coordination/handoffs/*.md`)
- requires docs/policy evidence for functional changes (`README.md` or `policy/*.md`/equivalent docs)
- **significant logic documentation contract**:
  - if changes affect requirements/behavior/capabilities enforcement logic (for example gate scripts, validators, install/deploy core, policy profiles/rules), `README.md` update is mandatory in the same change set
  - gate check: `significant-doc-sync`
- blocks modification of existing tests/evals by default (new tests allowed)
- blocks architecture/design file changes by default (`SPEC.md`, `ARCHITECTURE.md`, `docs/design/*`, `docs/architecture/*`)
- allows exceptions only with explicit override record: `coordination/approval-overrides.json`
- requires post-implementation review report (`coordination/reviews/*.md`) validated by:
  - `scripts/validate-review-report.ps1` (Windows)
  - `scripts/validate-review-report.sh` (Linux/macOS)
7. Cycle-proof gate:
- `scripts/validate-cycle-proof.ps1` (Windows)
- `scripts/validate-cycle-proof.sh` (Linux/macOS)
- enforces `coordination/cycle-contract.json`
- checks required review/handoff artifacts
- checks independent review (`Reviewer` must differ from `Implementation Agent`)
- checks required verification commands are present in the review report
- checks iteration-size limits (`max_functional_files`, `max_diff_lines`) with explicit override only

## Cross-System Coverage

The gate and integrity checks enforce consistency for all target systems:

- Claude
- Codex
- Cursor
- Gemini
- OpenCode

## Decision

- `PASS`: all mandatory checks passed.
- `FAIL`: at least one mandatory check failed and task must not be marked complete.
- `WARN`: non-blocking limitation (for example, `bash` not available on host) must be reported explicitly.
