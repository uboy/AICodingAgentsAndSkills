# Eval Case: code-review

## Input Scenario

A mixed-language PR with local changes and one potential high-risk bug.

## Acceptance Checks

1. Review scope selection is explicit (local/branch/commit).
2. Findings are severity-ranked.
3. Every finding references concrete file location.
4. Output contains actionable fix guidance and verification steps.
