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
