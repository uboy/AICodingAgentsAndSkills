---
name: ci-failure-debugger
description: Diagnose CI failures and produce minimal, verifiable remediation plans.
---

# Skill: ci-failure-debugger

## Purpose

Find root causes of CI failures and define smallest safe fix path.

## Use When

- User asks to debug failing CI jobs.
- Build/test/lint/package/deploy pipelines are red.

## Do Not Use When

- No CI logs or failing signal are available.

## Input

- CI logs, failing job names, related diff, workflow config.

## Safety Rules

1. Separate infrastructure flakiness from deterministic code failures.
2. Base root cause on first meaningful failing signal.
3. Keep fixes minimal and reversible.

## Workflow

1. Classify failure type and stage.
2. Correlate failure with code/config/environment changes.
3. Validate root-cause hypothesis with smallest local check.
4. Provide fix plan plus fallback/rollback notes.

## Output Format

1. Failure summary.
2. Root cause with evidence.
3. Minimal fix plan and verification commands.
4. Risk and fallback notes.

## Self-Check

- Root cause is evidence-backed.
- Proposed fix is testable and scoped.
