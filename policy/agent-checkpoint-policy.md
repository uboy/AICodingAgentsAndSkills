# Agent Checkpoint Policy

## Rule: Every agent MUST checkpoint after every meaningful action.

This prevents context loss on disconnection, session expiry, or handoff between agents.

## What to Checkpoint

After each of these actions, update your state file:

| Action | What to save |
|--------|-------------|
| Read a file | `last_action: "read <path>"` |
| Edit a file | `last_action: "edited <path> (+N/-M lines)"` |
| Run a command | `last_action: "ran: <command>"` + result |
| Complete a verified chunk | `last_action: "verified chunk <id>"` + brief refresh summary |
| Complete a task step | `status: "done"`, update checklist |
| Encounter an error | `status: "error"`, `notes: "<error details>"` |
| Hit rate limit | `status: "rate_limited"`, `resume_after_utc` |
| Start/stop work | `status: "in_progress"` / `"idle"` |

## State File Format

File: `coordination/state/<agent-name>.md`

```markdown
# Agent State

- agent: <agent-name>
- task_id: <task-id>
- status: idle | in_progress | done | blocked | error | rate_limited
- last_updated_utc: <ISO-8601>
- workspace: <repo-root>
- last_action: <what was just done>
- last_action_result: <brief outcome>
- next_action: <what should happen next>
- retry_count: <N>
- consecutive_same_action: <description or null>
- notes:
  - <any relevant context>
  - <decisions made and why>
  - <execution brief refresh: current objective, boundary, rules, next acceptance>
```

## Checklist Update

File: `coordination/tasks.jsonl`

Each task entry:

```jsonl
{"id": "T-001", "title": "Add feature X", "owner": "implementation-developer", "status": "in_progress", "checklist": [{"id": "C-1", "text": "Read requirements", "status": "done"}, {"id": "C-2", "text": "Implement feature", "status": "in_progress"}, {"id": "C-3", "text": "Run tests", "status": "todo"}], "updated_at": "2026-04-11T12:00:00Z"}
```

## Checkpoint Script

Use the checkpoint script for programmatic updates:

```powershell
# Windows
pwsh -NoProfile -File scripts/agent-checkpoint.ps1 -Agent <name> -TaskId <id> -Status in_progress -Action "edited src/foo.py" -Note "Added null check"

# Linux/macOS
bash scripts/agent-checkpoint.sh --agent <name> --task-id <id> --status in_progress --action "edited src/foo.py" --note "Added null check"
```

## Why This Matters

1. **Session recovery**: If Qwen/Claude/Codex disconnects, next agent resumes from last checkpoint
2. **Multi-agent sync**: Different agents see the same state, no duplicate work
3. **Audit trail**: Who did what, when, and why
4. **Loop detection**: `retry_count` and `consecutive_same_action` catch infinite loops
5. **Rule retention**: chunk-boundary checkpoint refresh keeps objective, rules, and scope alive during long work

## Enforcement

- Agents that skip checkpointing for >3 actions in a row FAIL policy review
- Long-running tasks that cross chunk boundaries without refreshing the active execution brief FAIL policy review
- `code-review-qa` must verify checkpoint updates exist in any implementation PR
- `wm-orchestrator` blocks dispatch if state file is stale (>30 min old)
