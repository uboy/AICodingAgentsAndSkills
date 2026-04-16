# Handoff Template

Use this as a local handoff artifact by default. It is not meant to be committed automatically on every task.

## Task

- ID: <task-id>
- Owner: <agent>

## Summary

<what changed>

## Files Touched

- <path 1>
- <path 2>

## Verification

- `<command 1>` -> <result>
- `<command 2>` -> <result>

## Risks / Follow-ups

- <item 1>

## Commit Readiness

Ready to commit.

Or:

Not commit-ready.
- blocker: <reason 1>
- blocker: <reason 2>

## Delivery Contract

Commit pending user approval.

---

## Example: Ideal Execution

### Task
- ID: T-20260224-120000
- Owner: gemini

### Summary
Implemented `generate-task.ps1` and `.sh` to automate task creation.

### Files Touched
- scripts/generate-task.ps1
- scripts/generate-task.sh
- README.md

### Verification
- `pwsh scripts/generate-task.ps1` -> PASSED (Task added to tasks.jsonl)
- `bash scripts/generate-task.sh` -> PASSED (Task added to tasks.jsonl)

### Risks / Follow-ups
- Ensure python3 is installed for .sh script.

### Commit Readiness
Ready to commit.

### Delivery Contract
Commit pending user approval.
