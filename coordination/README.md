# Multi-Agent Coordination Protocol

This directory is the single shared channel for parallel agent runs (Claude, Codex, Gemini, Cursor, OpenCode).

## Goals

- Keep agent contexts isolated per console/session.
- Synchronize progress through files, not through shared chat memory.
- Prevent concurrent edits to the same target without an explicit lock.

## Structure

- `tasks.jsonl`: task queue in JSON Lines format.
- `state/`: per-agent current status and heartbeat.
- `handoffs/`: completed task outputs, decisions, and review artifacts.
- `locks/`: file-based locks for shared resources.
- `PLAN-TASK-PROTOCOL.md`: shared plan/handoff protocol.
- `templates/`: task/plan/handoff templates.
- `tool-usage.sample.jsonl`: sample input for tool summary formatting.

## Task Record Format (`tasks.jsonl`)

Each line is one JSON object:

```json
{"id":"T-001","title":"Add text-editor agent","owner":"claude","status":"todo","priority":"high","checklist":[{"id":"C-1","text":"Implement change","status":"todo"},{"id":"C-2","text":"Run verification","status":"todo"}],"depends_on":[],"inputs":[".claude/agents"],"outputs":[".claude/agents/text-editor.md"],"updated_at":"2026-02-23T00:00:00Z"}
```

Allowed `status`: `todo`, `in_progress`, `blocked`, `done`.
Checklist item status: `todo`, `in_progress`, `blocked`, `done`.

### Interactive Task Generator

To add a new task to the queue, use:

**Windows:**
```powershell
pwsh -NoProfile -File .\scripts\generate-task.ps1
```

**Linux / macOS:**
```bash
bash ./scripts/generate-task.sh
```

The generator supports two modes:
1. **AI Mode (Recommended)**: You provide a raw idea, and the agent uses the `task-specifier` skill to research relevant files and propose a technical plan.
2. **Manual Mode**: Standard interactive prompts for all fields.

## Locking Rule

Before editing a shared file or directory, create a lock file:

- `locks/<resource>.lock`

Lock file content should include:

- `owner`
- `task_id`
- `timestamp`

Remove lock only after commit or explicit handoff.

## Handoff Rule

When a task is complete, write:

- `handoffs/<task-id>-<agent>.md`

Include:

1. What changed.
2. Files touched.
3. Verification commands and outcomes.
4. Risks or follow-up items.

## Branching Rule

- One branch/worktree per agent: `agent/<name>`.
- Integration happens in order through `scripts/sync-agents.*`.

## Conflict Avoidance

1. Do not edit another agent's lock-owned files.
2. Do not force-push shared branches.
3. Resolve merge conflicts in integrator flow only.

## Optional Tool-Use Summary

Compact mode (default):

```powershell
pwsh -NoProfile -File .\scripts\format-tool-summary.ps1 -InputFile .\coordination\tool-usage.sample.jsonl -Mode compact
```

```bash
bash ./scripts/format-tool-summary.sh --input-file ./coordination/tool-usage.sample.jsonl --mode compact
```

Full mode:

```powershell
pwsh -NoProfile -File .\scripts\format-tool-summary.ps1 -InputFile .\coordination\tool-usage.sample.jsonl -Mode full
```

```bash
bash ./scripts/format-tool-summary.sh --input-file ./coordination/tool-usage.sample.jsonl --mode full
```
