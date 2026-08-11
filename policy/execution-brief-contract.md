# Execution Brief Contract

Canonical contract for coordinator-side request refinement, long-task rule refresh, and chunked execution discipline.

This contract exists to improve execution quality before downstream delegation.

## Purpose

Before a coordinator delegates work or starts a multi-step execution flow, it should transform the raw user request into an operationally better execution brief.

The execution brief is responsible for making explicit:
- what the real objective is;
- what output shape is expected;
- what constraints matter;
- what assumptions are forbidden;
- what sources are relevant;
- whether source prep is recommended;
- whether code work must be chunked;
- what rules must stay active during long work;
- what verification defines success.

## Where It Applies

Required for:
- non-trivial `repo_change`
- multi-step `content_task`

Recommended for:
- larger `repo_read` investigations where scope or evidence can drift

## Brief Ownership

Initial ownership:
- `team-lead-orchestrator`

Refresh ownership during execution:
- the currently executing agent for chunk-level refresh
- the coordinator again when scope, routing, or delegation target changes materially

## Required Execution Brief Fields

- `task_profile`
- `task_shape`
- `refined_objective`
- `user_intent`
- `output_expectation`
- `hard_constraints`
- `forbidden_assumptions`
- `relevant_sources`
- `source_prep_recommendation`
- `active_rules`
- `subtask_boundary`
- `success_criteria`
- `verification_requirements`
- `chunking_requirement`
- `long_task_refresh`

Use `coordination/templates/execution-brief.json` as the tracked template.

## Request-Refinement Rules

The refined brief must improve the raw request, not merely restate it.

The coordinator must:
1. identify the real task shape;
2. clarify the likely output form;
3. surface hidden constraints and forbidden shortcuts;
4. decide whether source prep is recommended;
5. identify the smallest downstream component that can do the job;
6. decide whether code work must be chunked;
7. define verification before delegation.

## Long-Task Rule Refresh

The active execution brief must be refreshed when any of these happen:
- before handing work to another agent or skill;
- after each verified code chunk;
- after a blocker, stall, or failed verification;
- after scope expansion;
- before resuming a paused or interrupted task.

Refresh means restating:
- the refined objective;
- active rules and constraints;
- source limits;
- current subtask boundary;
- next acceptance criteria.

## Large-Codebase Chunking

Code work defaults to `small_isolated_verified_chunks`.

That means:
1. choose the smallest meaningful change unit;
2. keep the primary file scope narrow;
3. change one chunk at a time;
4. verify before the next chunk;
5. refresh the brief before expanding scope;
6. expand file scope only when the current chunk is genuinely blocked.

## Integration With Academic Source Handling

The execution brief should explicitly carry source-handling choices:
- whether `scripts/study-materials-prep.py` is recommended;
- whether prepared source packs or raw curated excerpts are preferred;
- whether fallback to originals matters;
- which academic skill fits the task shape best.

This keeps academic source discipline integrated with coordinator routing instead of hidden inside downstream prompts.
