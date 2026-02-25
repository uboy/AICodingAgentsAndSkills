---
name: code-review
description: Review code changes via local diff, branch diff, or latest commit with severity-ranked findings and concrete fixes.
---

# Skill: code-review

## Purpose

Perform robust code review of changed files and report actionable issues by severity.

## Use When

- User asks to review code, commit, or PR changes.
- Need a quality gate before merge.

## Do Not Use When

- Task is implementation-only without review intent.
- No change scope can be identified.

## Input

- Changed files and diff scope.
- Optional target branch (`TARGET_BRANCH`) for pre-PR scope.
- Optional project-specific lint/static-check commands.

## Safety Rules

1. Base every finding on concrete code evidence with file references.
2. Do not claim vulnerabilities or regressions without traceable reasoning.
3. Distinguish clearly between blocking issues and optional improvements.

## Workflow

1. Detect scope: local changes, pre-PR branch diff, or latest commit.
2. Classify changed files by language and risk area.
3. Review dimensions: static checks, architecture, correctness, security, performance, tests, stability.
4. Produce severity-ranked findings and exact remediation guidance.

## Output Format

1. Review Summary (scope, files, overall assessment).
2. Findings: Critical, High, Medium, Low.
3. Per finding: `severity | file:line | issue | impact | fix`.
4. Verification steps and commands.

## Self-Check

- All changed files were considered.
- Findings include specific evidence.
- Recommendations are testable and minimally invasive.
