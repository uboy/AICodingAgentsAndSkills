# Eval Case: large-codebase-context

## Input Scenario

Very large polyrepo-like workspace; user asks for safe implementation strategy with strict context limits to avoid hallucinations.

## Acceptance Checks

1. Plan uses scoped retrieval and micro-steps.
2. Claims are linked to explicit `path:line` evidence.
3. Checkpoint/state workflow is present and actionable.
