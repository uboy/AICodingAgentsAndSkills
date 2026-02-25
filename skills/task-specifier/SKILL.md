---
name: task-specifier
description: Transforms raw user ideas into structured, technical task records for tasks.jsonl.
---

# Skill: task-specifier

## Purpose
Help users define high-quality, actionable tasks by researching the codebase and proposing inputs, outputs, and checklists.

## Input
- Raw task idea or goal from user.
- Current codebase context (via tools).

## Shared Safety
Apply baseline rules from `../_shared/TEXT_GUARDRAILS.md`.

## Workflow

1. **Analyze Raw Idea**: Understand the core intent of the user's request.
2. **Codebase Research**: 
   - Use `grep_search` or `list_directory` to find relevant files.
   - Identify which files will be read (inputs) and which will be modified (outputs).
3. **Propose Specification**:
   - Suggest a clear, technical `title`.
   - Propose a `priority`.
   - Create a detailed `checklist` with 3-7 actionable steps.
   - Include `inputs` and `outputs` as absolute-ready relative paths.
4. **Refine with User**:
   - Present the proposal to the user.
   - Ask: "Does this cover everything? Are these the right files?"
5. **Finalize JSON**: Generate the final JSON line for `tasks.jsonl`.

## Mandatory Rules
- **No Guessing**: If files aren't found, ask the user or mark as `todo` in checklist to find them.
- **Cross-OS Safety**: Ensure paths use forward slashes `/` for consistency.
- **Micro-steps**: For weak models, ensure each checklist item is a single atomic change (Rule 23).

## Output Format
Return a structured proposal followed by the final JSON block labeled `TASK_JSON`.

## Tool Usage for Automation
After the user approves the proposal, the agent SHOULD execute the following command to finalize the task in `tasks.jsonl`:

**Windows:**
```powershell
pwsh -NoProfile -File ./scripts/generate-task.ps1 -JsonLine '<TASK_JSON>'
```

**Linux / macOS:**
```bash
bash ./scripts/generate-task.sh --json '<TASK_JSON>'
```
