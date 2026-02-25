---
name: ios-code-review
description: Review iOS code for lifecycle safety, concurrency correctness, security, performance, and test gaps.
---

# Skill: ios-code-review

## Purpose

Review iOS (Swift/Obj-C/Xcode/SwiftUI/UIKit) changes for platform-specific risks and regressions.

## Use When

- User asks for iOS code review.
- Diff touches app lifecycle, concurrency, entitlements, networking, persistence, or UI state.

## Do Not Use When

- No iOS-specific code is involved.

## Input

- Changed iOS files and related tests.
- Build/test context if available.

## Safety Rules

1. Prioritize crash/privacy/entitlement issues.
2. Validate concurrency and memory/resource claims with evidence.
3. Keep recommendations feasible for Apple platform APIs.

## Workflow

1. Inspect lifecycle, concurrency, memory/resource ownership, privacy permissions.
2. Assess correctness, performance, and compatibility impact.
3. Identify testing gaps and propose concrete tests.

## Output Format

1. Findings by severity.
2. Each finding: `severity | file | issue | impact | fix`.
3. Missing tests and residual risks.

## Self-Check

- iOS-specific lifecycle and platform constraints were covered.
- Evidence links each issue to code.
