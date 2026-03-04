# PROJECT AGENTS POLICY (WEAK CONTEXT PROFILE)

This policy is optimized for weak models (small context windows) and applies to both Claude Code and Codex.

## 1. Startup Ritual (Mandatory)

Before any edits or non-read action:
1. Read `coordination/tasks.jsonl`.
2. Read `coordination/state/<agent>.md`.
3. If there is an `in_progress` task owned by the current agent, resume it first.

## 2. Task Classification (Mandatory)

- `Trivial`: exact tiny change, one file, no design choice.
- `Non-trivial`: multi-file, unknown root cause, API/behavior/design impact.

For non-trivial tasks, use:
1. Research notes in `.scratchpad/research.md`.
2. Plan in `.scratchpad/plan.md`.
3. Checklist in `coordination/tasks.jsonl`.
4. Implementation in micro-steps.
5. Review handoff in `coordination/handoffs/`.

## 3. Weak-Model Micro-Step Rules

- One operation per step.
- Max files changed per step: `3`.
- Max changed lines per step: `50`.
- No silent assumptions: unresolved ambiguity must be asked explicitly.
- After each mutation step run a verification command.

## 4. Persistence Contract

After each meaningful step:
- update `coordination/state/<agent>.md`,
- update checklist item status in `coordination/tasks.jsonl`,
- store long logs/snippets in `.scratchpad/` and keep only short summary in state.

## 5. Delivery Contract

- Do not commit unless user explicitly says `commit`.
- Provide a ready-to-use commit message block in final delivery.
- If not committed, final status must say: `Commit pending user approval`.

## 6. Output Contract (for handoff/final)

Include:
- `changed_files`,
- `verification` commands and pass/fail,
- `open_questions` or `none`,
- `risks` or `none`.
