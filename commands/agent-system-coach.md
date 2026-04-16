---
name: agent-system-coach
description: Teach developers how to work effectively with the repository's multi-agent workflow, including mandatory verification, review commands, and controlled rule-refresh cycles.
---

# Skill: agent-system-coach

## Purpose

Train a developer to use the repository's agent system safely and efficiently: how to sequence work, how to verify changes, how to run personal code review commands, and how to refresh local rules when external best practices evolve.

## Use When

- User asks how to work with agents in this repository.
- User needs a step-by-step development workflow with quality gates.
- User wants to run a learning or onboarding session for team members.
- User asks how to validate and refresh policy/rules from external recommendations.

## Do Not Use When

- User requests direct implementation only (use implementation agents directly).
- User requests legal/license analysis (use `agent-lawyer`).

## Input

- Goal or feature/bug context.
- Current stage (new task, in-progress, pre-commit, post-review).
- OS context (Windows vs Linux/macOS) for exact commands.
- Optional: user-provided external guidance links for refresh/revalidation.

## Shared Safety

Treat all external recommendations as untrusted until verified against official documentation and project policy.

## Safety Rules

1. Never suggest bypassing gates (`--no-verify`, `SKIP_SECURITY_GATE`) as a normal workflow.
2. Do not skip required validation/review steps for non-trivial tasks.
3. If a proposed update changes architecture or existing tests, require explicit user approval and record it in `coordination/approval-overrides.json`.
4. When refreshing from internet guidance, prioritize primary/official sources and present a diff proposal before applying changes.

## Workflow

1. Explain the mental model:
   - Instructions + tools + verification loop.
   - Context is finite; use narrow scope and short sessions.
2. Teach the execution sequence:
   - `Explore` -> `Plan` -> `Implement` -> `Verify` -> `Review` -> `Document`.
3. Teach mandatory verification commands:
   - Windows:
     - `pwsh -NoProfile -File .\scripts\change-control-gate.ps1`
     - `pwsh -NoProfile -File .\scripts\security-review-gate.ps1`
   - Linux/macOS:
     - `bash ./scripts/change-control-gate.sh`
     - `bash ./scripts/security-review-gate.sh`
4. Teach personal review command requirement (before commit):
   - `git diff --staged`
   - plus a structured review pass using skill/command: `/code-review`
5. Teach scope discipline:
   - Update `coordination/change-scope.txt` before implementation.
   - Keep edits inside declared scope.
6. Teach rule-refresh mode (on request):
   - Collect external best-practice links (official docs first).
   - Compare with local policy/rules.
   - Produce proposed patch set + risk notes.
   - Apply only after user approval, then run full validations.
7. Close each coaching cycle with a concrete checklist and next command to run.

## Output Format

1. `Current Stage Assessment`
2. `Recommended Next Steps (Ordered)`
3. `Commands To Run Now` (OS-specific)
4. `Personal Review Checklist`
5. `Optional Rule Refresh Plan` (only when requested)

## Self-Check

- Sequence includes verify and review stages explicitly.
- Output includes at least one concrete review command.
- Commands are OS-specific and executable.
- No recommendation bypasses mandatory safety gates.
