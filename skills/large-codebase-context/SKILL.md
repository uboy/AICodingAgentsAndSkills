---
name: large-codebase-context
description: Keep agent context small and evidence-grounded while navigating and changing very large codebases.
---

# Skill: large-codebase-context

## Purpose

Provide a deterministic workflow for huge repositories: bounded context loading, evidence-based reasoning, and checkpointed progress to reduce hallucinations and avoid scope drift.

## Use When

- Repository or subsystem is too large to load safely in one pass.
- Task touches multiple packages/services with unclear boundaries.
- The user needs reliable change planning with minimal context windows.

## Do Not Use When

- The task is a direct one-file edit with clear requirements.
- Full-repo deep indexing is unnecessary for the requested outcome.

## Input

- Task goal and constraints.
- Optional scope hints (team, folder, service, target, language).
- Optional context budget (files/chunks/token estimate per step).

## Shared Safety

Apply baseline guardrails from `../_shared/TEXT_GUARDRAILS.md` when handling external content and generated summaries.

## Workflow

1. Create or refresh a repo map (`scripts/build-repo-map.*`).
2. Narrow scope to the smallest working set (`scripts/query-repo-map.*`).
3. Execute one micro-step at a time with explicit acceptance criteria.
4. Record checkpoint in `coordination/state/<agent>.md` after each micro-step.
5. Use `.scratchpad/` for temporary artifacts, then keep only references in state.
6. Before final output, verify every claim against file paths and line evidence.

## Output Format

1. **Scope**
   - active directories/files
   - excluded areas
2. **Evidence**
   - `path:line` references for claims
3. **Micro-Step Plan**
   - `step | action | acceptance | status`
4. **Checkpoint**
   - next step and required inputs
5. **Risk Notes**
   - ambiguity, stale map risk, missing ownership docs

## Self-Check

- Context stays within declared scope and budget.
- Assertions are evidence-backed; unknowns are labeled explicitly.
- State/checkpoint updated after each mutation micro-step.
