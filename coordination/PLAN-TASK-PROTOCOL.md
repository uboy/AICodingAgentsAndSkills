# Plan And Task Protocol

This protocol standardizes handoff between agents and sessions.

## Plan Schema

Each plan should include:

1. `goal`: one sentence objective.
2. `constraints`: key limits (OS, tools, permissions, deadlines).
3. `steps`: ordered list with status (`pending`, `in_progress`, `completed`, `blocked`).
4. `verification`: commands/checks required for completion.

## Execution Brief Schema

Before delegation or multi-step execution, create an execution brief using:
- `coordination/templates/execution-brief.json`

Suggested local runtime location:
- `coordination/briefs/<task-id>.json`

Required fields:

1. `task_profile`
2. `task_shape`
3. `refined_objective`
4. `user_intent`
5. `output_expectation`
6. `hard_constraints`
7. `forbidden_assumptions`
8. `relevant_sources`
9. `source_prep_recommendation`
10. `active_rules`
11. `subtask_boundary`
12. `success_criteria`
13. `verification_requirements`
14. `chunking_requirement`
15. `long_task_refresh`

## Task Record Schema

When you use the local coordination workflow, task records in `coordination/tasks.jsonl` should include:

1. `id`
2. `title`
3. `owner`
4. `status`
5. `checklist` (array of checklist items with status)
6. `depends_on`
7. `inputs`
8. `outputs`
9. `updated_at`
10. `execution_brief_ref`

Checklist item schema:

1. `id`
2. `text`
3. `status` (`todo`, `in_progress`, `done`, `blocked`)

## Handoff Contract

When you use the local coordination workflow, each completed task should create `coordination/handoffs/<task-id>-<agent>.md` including:

1. Summary of changes.
2. Files touched.
3. Verification commands and results.
4. Risks/blockers/follow-ups.

## Blocking Rule

If requirements are ambiguous and can change behavior or safety, mark task `blocked` and request clarification before implementation.

## Checklist Rule

For non-trivial tasks (multiple files/steps), checklist tracking is mandatory:

1. Create checklist before implementation.
2. Keep exactly one item in `in_progress` at a time.
3. Mark incomplete items as `blocked` with reason if task cannot proceed.
4. Ensure verification/doc/security-gate items are present and completed before handoff.
5. If you are using the local cycle-proof workflow, define or update `coordination/cycle-contract.json` before implementation.
6. Keep the execution brief reference current when the active subtask, constraints, or file scope change materially.

## Micro-Step Execution for Weak Models

Follow Rule 23 of `AGENTS.md`. For models in `weak_model` profile:
1. Break work into steps of ≤ 50 lines.
2. Mandatory self-check after each mutation step: run `syntax check`, `linter`, or `security-review-gate`.
3. Stop and verify output before proceeding to the next step.

## One-Shot Examples (Ideal Execution)

Agents should consult `coordination/templates/` for "Ideal Execution" examples. Following these patterns is mandatory for high-quality delivery.

## Checkpointing and State Management

To ensure context persistence (Rule 28), agents MUST maintain `coordination/state/<agent>.md` with the following schema:

- `active_task_id`: current task from `tasks.jsonl`.
- `last_completed_step`: ID from the task checklist.
- `pending_context`: concise summary of current logic, variables, and next immediate action.
- `artifacts`: list of paths in `.scratchpad/` containing temporary logs, diffs, or plans.

This file acts as the agent's "external memory" and MUST be updated after every checklist item completion.

## Long-Task Refresh Rule

For long tasks or large-codebase work, refresh the active execution brief:

1. before delegation;
2. after each verified chunk;
3. after blockers or failed verification;
4. before resuming after interruption.

Each refresh should restate:
- refined objective,
- active rules,
- source constraints,
- current subtask boundary,
- next acceptance criteria.

Tracked vs local rule:

- `coordination/state/<agent>.md` and `coordination/state/session-usage.json` are local runtime files, not canonical review artifacts.
- Active runtime instances may be bootstrapped automatically when missing.
- Handoffs, reviews, task queue, scope, cycle contract, and approval overrides are local runtime files by default.
- The repository keeps templates and protocol docs only; live execution records should stay local unless explicitly exported.

## Testing and Verification

To ensure stability (Rule 29), agents MUST:

1. **Include Tests**: every plan must have a dedicated step for creating or updating automated tests.
2. **Execute Tests**: every handoff must report the execution of these tests with their full output (or a concise summary if too large).
3. **Regression Check**: before completing a fix, the agent must run existing project tests to ensure no regressions were introduced.
4. **Cross-OS Validation**: scripts/automation changes must be verified on both Windows (PS1) and Linux/macOS (SH) where possible.
5. **Balanced Elegance**: for non-trivial tasks, include a "Design Review" step to ensure the solution is elegant and simple.
6. **Autonomous Ownership**: when a bug report or CI failure is the input, the agent takes full responsibility for investigation and fix.
7. **Optional Local Review Artifact**: if you use the local review pipeline, create `coordination/reviews/<task-id>-<agent>.md` using `coordination/templates/review-report.md`.
8. **Review Validation**: when local review reports are used, ensure they pass `scripts/validate-review-report.ps1` (Windows) and `scripts/validate-review-report.sh` (Linux/macOS).
9. **Cycle-Proof Validation**: when a local cycle contract is used, ensure it passes `scripts/validate-cycle-proof.ps1` (Windows) and `scripts/validate-cycle-proof.sh` (Linux/macOS).
