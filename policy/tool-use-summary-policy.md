# Tool Use Summary Policy

This policy keeps verification transparent without overloading normal responses.

## Modes

1. `compact` (default): short summary with only actionable items.
2. `full`: detailed per-command report.

## Compact Output Rules

1. Maximum 5 bullets.
2. Include:
- commands executed count,
- failed commands count,
- write/network actions count,
- critical blockers only.
3. Omit routine read-only command details.

## Full Output Rules

1. Per-command rows including command, type, result.
2. Use only when:
- user explicitly requests details, or
- debugging/audit requires complete trace.

## Script Support

Use:

- `scripts/format-tool-summary.ps1`
- `scripts/format-tool-summary.sh`

Default mode is `compact` to avoid noisy output.
