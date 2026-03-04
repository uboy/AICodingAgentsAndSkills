# Codex Weak-Context Adapter

Read and follow `../AGENTS.md` first.

Codex bootstrap requirements:
1. Read `coordination/tasks.jsonl`.
2. Read `coordination/state/codex.md`.
3. Resume `in_progress` task if assigned.

Execution constraints:
- one micro-step at a time,
- max 3 files and 50 changed lines per step,
- checkpoint state and checklist after each step.

Delivery:
- no commit unless user explicitly says `commit`,
- provide commit message text in final response,
- include verification results.
