# Skills Eval Baseline

This folder stores lightweight regression cases for local skills.

## Goals

- Keep skill behavior stable after prompt edits.
- Detect accidental schema drift in outputs.
- Catch safety regressions (fabrication, missing redaction, missing uncertainty markers).

## Structure

- `cases/<skill-name>.md`: manual eval scenario and acceptance checks.

## Run

Windows:

```powershell
pwsh -NoProfile -File .\scripts\validate-skills.ps1
```

Linux/macOS:

```bash
bash ./scripts/validate-skills.sh
```

## Notes

- These are baseline contract checks, not full semantic scoring.
- Expand cases when new skills are added or output formats change.

## Reliability Metrics

Use these metrics when comparing baseline vs weak-model overlay behavior:

- `pass@k`: task considered successful if at least one out of `k` attempts passes all acceptance checks.
- `pass^k` (all-pass): task considered successful only if all `k` attempts pass.

Suggested defaults:

- `k = 3` for quick smoke reliability checks.
- `k = 5` for release-gate checks on weak models.

Interpretation:

- High `pass@k` + low `pass^k` means outcomes are inconsistent and require tighter step contracts.
- High `pass@k` + high `pass^k` means behavior is both capable and stable.
