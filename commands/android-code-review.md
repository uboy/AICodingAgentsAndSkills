---
name: android-code-review
description: Review Android code for lifecycle safety, threading, correctness, security, performance, and test gaps.
---

# Skill: android-code-review

## Purpose

Review Android (Kotlin/Java/Gradle/Compose/XML) changes for mobile-specific defects and risks.

## Use When

- User asks for Android code review.
- Diff touches Android app modules, lifecycle, permissions, storage/network, UI state.

## Do Not Use When

- No Android-specific code is involved.

## Input

- Changed Android files and related tests.
- Build/test context if available.

## Safety Rules

1. Prioritize crash/data-loss/privacy risks.
2. Require evidence for lifecycle/threading claims.
3. Avoid framework assumptions unsupported by code.

## Workflow

1. Check lifecycle, concurrency, permissions, storage/network, and UI state handling.
2. Validate correctness and regression risk.
3. Evaluate performance and test coverage.
4. Produce ranked findings with concrete fixes.

## Output Format

1. Findings by severity.
2. Each finding: `severity | file | issue | impact | fix`.
3. Missing tests and residual risks.

## Self-Check

- Android-specific APIs and lifecycle were evaluated.
- Findings are reproducible from diff/context.
