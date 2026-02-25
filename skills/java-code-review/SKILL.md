---
name: java-code-review
description: Review Java code for correctness, concurrency safety, security, performance, and test completeness.
---

# Skill: java-code-review

## Purpose

Review Java/JVM code changes for correctness and maintainability with emphasis on thread safety and resource handling.

## Use When

- User asks for Java code review.
- Diff includes Java services/libraries/tests/build config.

## Do Not Use When

- No Java/JVM code is changed.

## Input

- Changed Java files and tests.
- Build/test context (Maven/Gradle/JUnit) if available.

## Safety Rules

1. Prioritize concurrency, nullability, and resource-safety issues.
2. Avoid speculative findings without file-level evidence.
3. Mark uncertain assumptions explicitly.

## Workflow

1. Validate correctness and edge-case behavior.
2. Check threading/shared-state/locking behavior.
3. Assess API usage, exception handling, and resource cleanup.
4. Report severity-ranked issues and missing tests.

## Output Format

1. Findings by severity.
2. Each finding: `severity | file | issue | impact | fix`.
3. Suggested tests and residual risk notes.

## Self-Check

- Concurrency and exception/resource paths were reviewed.
- Recommendations are specific and actionable.
