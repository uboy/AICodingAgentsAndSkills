---
name: security-review
description: Review changes for exploitable vulnerabilities, trust-boundary issues, and insecure secret handling.
---

# Skill: security-review

## Purpose

Detect security weaknesses in changed code and provide practical mitigations by adopting specialized security personas and focusing on specific threat vectors.

## Use When

- User asks for security review.
- Diff affects input handling, auth, crypto, storage, permissions, or secrets.

## Do Not Use When

- No code path or trust-boundary behavior changed.

## Role Selection (Persona)

Before starting the review, implicitly adopt the most relevant persona based on the context:
- **Senior Security Engineer**: Focus on base vulnerabilities (SQLi, NoSQLi, XSS, insecure deserialization, leak of sensitive data in logs).
- **Pentester (Auth Bypass)**: Focus on JWT (algorithm, signature, expiry), session management (fixation, invalidation), and privilege escalation (IDOR, client-side checks).
- **Application Security Engineer**: Trace every external input (query params, POST body, headers, files) from entry point to execution/sink (DB, OS command, rendering) and check for validation/sanitization.
- **Supply Chain Security Engineer**: Focus on dependencies, known CVEs, outdated versions, and transitive risks.

## Input

- Changed files and relevant integration points.

## Safety Rules

1. Focus on exploitable paths and privilege boundaries.
2. Avoid vulnerability claims without threat-path evidence.
3. Never expose or copy sensitive values in output.

## Workflow

1. Map untrusted inputs and boundary crossings (follow data from entry to sink).
2. Check validation, authz, secret handling (hardcoded keys, cleartext passwords), and dependency risk.
3. Focus specifically on JWT/session logic and access control if present.
4. Rank issues by exploitability and impact (Critical and High first).
5. Provide secure fix strategy and test requirements.

## Output Format

1. Findings by severity (Critical and High first, then others).
2. For each finding, strictly use a tabular format or clearly delimited structure:
   `Severity | File:Line | Vulnerability | Exploit Path (Payload) | Fix Fragment`
   *(Do not describe theory, bind every finding to exact line numbers)*
3. If no vulnerabilities found - state this explicitly.
4. Required security tests/guards.

## Self-Check

- Each issue has an explicit threat path and specific payload example.
- Findings are tied to exact line numbers.
- Fixes reduce risk without undocumented tradeoffs.
