# Agent Knowledge Memory Policy

This policy defines how to retain and revalidate reusable operational knowledge
without loading full historical context into every task.

## Scope

- Applies to Claude, Codex, Cursor, Gemini, OpenCode.
- Applies to reusable corrections: deprecations, API migrations, recurring failures,
  workflow/config fixes.

## Storage Model

- Index: `.agent-memory/index.jsonl`
- Detailed entries: `.agent-memory/entries/<technology>/<id>.md`

Required index fields:

- `id`
- `technology`
- `skills` (array)
- `applies_to_systems` (array)
- `summary`
- `source_links` (array)
- `recorded_on`
- `last_verified_on`
- `verify_after_days`
- `status` (`active`, `stale`, `retired`)
- `trigger` (`user_report`, `runtime_warning`, `runtime_error`, `manual_review`)

## Retrieval Rules

- Select entries by task technology/skill first.
- Load only matching entries.
- Avoid loading full memory index and all details by default.

## Revalidation Rules

Event-driven revalidation:

- user reports drift,
- runtime warning/error indicates outdated guidance,
- conflicting behavior is observed.

Time-driven revalidation:

- run freshness checks:
  - `scripts/check-knowledge-freshness.ps1` (Windows)
  - `scripts/check-knowledge-freshness.sh` (Linux/macOS)

## Commands

Windows:

```powershell
pwsh -File scripts/check-knowledge-freshness.ps1
```

Linux/macOS:

```bash
bash scripts/check-knowledge-freshness.sh
```

Impacted systems: Claude, Codex, Cursor, Gemini, OpenCode.
