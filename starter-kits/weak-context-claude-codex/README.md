# Weak Context Starter Kit (Claude Code + Codex)

This folder is a self-contained starter pack for teams that use weaker models with limited context windows.

It enforces a small-step workflow:
- one micro-step at a time,
- strict coordination artifacts,
- explicit state persistence between turns.

## Included

- `AGENTS.md`: shared weak-context policy.
- `CLAUDE.md`: thin Claude adapter.
- `.codex/AGENTS.md`: thin Codex adapter.
- `coordination/`: tasks, state files, and templates.
- `.scratchpad/`: temporary deep notes/logs.
- `scripts/`: cross-OS automation helpers (`ps1` + `sh`).

## Quick Start

### 1) Startup ritual

Windows:
```powershell
pwsh -NoProfile -File .\scripts\startup-ritual.ps1 -Agent codex
```

Linux/macOS:
```bash
bash ./scripts/startup-ritual.sh codex
```

### 2) Create a weak-model task

Windows:
```powershell
pwsh -NoProfile -File .\scripts\add-task.ps1 -Title "Implement one micro-fix" -Owner codex
```

Linux/macOS:
```bash
bash ./scripts/add-task.sh "Implement one micro-fix" codex
```

### 3) Run one micro-step, then checkpoint

Windows:
```powershell
pwsh -NoProfile -File .\scripts\checkpoint.ps1 -Agent codex -TaskId T-20260304-000001 -Status in_progress -Note "Step 1 done; syntax check passed."
```

Linux/macOS:
```bash
bash ./scripts/checkpoint.sh codex T-20260304-000001 in_progress "Step 1 done; syntax check passed."
```

### 4) Use templates for handoff/review

- Task schema: `coordination/templates/task.weak-model.json`
- Handoff template: `coordination/templates/handoff.md`
- State template: `coordination/templates/state.md`

## Recommended Workflow

1. Run startup ritual.
2. Pick exactly one file/function for the current micro-step.
3. Edit <= 50 lines.
4. Run the minimal verification command for that exact change.
5. Update `coordination/state/<agent>.md`.
6. Update checklist state in `coordination/tasks.jsonl`.
7. Write handoff note for the next agent.

## Notes

- This kit is intentionally minimal and portable.
- Copy this folder into a new project and adapt only paths and command examples.
