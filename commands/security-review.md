---
name: security-review
description: Review changes for exploitable vulnerabilities, trust-boundary issues, and insecure secret handling.
---

# Skill: security-review

## Purpose

Detect security weaknesses in changed code and provide practical mitigations.

## Use When

- User asks for security review.
- Diff affects input handling, auth, crypto, storage, permissions, or secrets.

## Do Not Use When

- No code path or trust-boundary behavior changed.

## Input

- Changed files and relevant integration points.

## Safety Rules

1. Focus on exploitable paths and privilege boundaries.
2. Avoid vulnerability claims without threat-path evidence.
3. Never expose or copy sensitive values in output.

## Workflow

1. Map untrusted inputs and boundary crossings.
2. Check validation, authz, secret handling, and dependency risk.
3. Rank issues by exploitability and impact.
4. Provide secure fix strategy and test requirements.

## Output Format

1. Findings by severity.
2. Each finding: `severity | file | vulnerability | exploit path | fix`.
3. Required security tests/guards.

## Self-Check

- Each issue has an explicit threat path.
- Fixes reduce risk without undocumented tradeoffs.
