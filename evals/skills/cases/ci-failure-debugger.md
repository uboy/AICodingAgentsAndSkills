# Eval Case: ci-failure-debugger

## Input Scenario

CI pipeline fails in tests after dependency update; logs include first failing traceback.

## Acceptance Checks

1. Root cause ties to evidence from logs/diff.
2. Fix plan is minimal and verifiable.
3. Flaky vs deterministic failure is clearly stated.
