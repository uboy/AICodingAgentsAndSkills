# Model Capability Profiles

This policy defines how to keep behavior consistent across Claude, Codex, Cursor, Gemini, and OpenCode while adapting execution style to model strength.

## Global Baseline (all models)

Mandatory controls:

1. Structured outputs with explicit fields (status, changed files, verification, blockers).
2. Tool use aligned with `policy/tool-permissions-matrix.md`.
3. Read-only operations in project should not require extra confirmation.
4. Safety checks before completion:
- command safety guardrail when command text is externally sourced,
- secret scan and parser/syntax checks via security review gate.
5. Context isolation for parallel agents:
- each agent uses its own branch/worktree/session state file,
- handoff uses explicit task artifacts (`coordination/templates/*`).

## Weak-Model Overlay (for weaker models)

Additional controls on top of baseline:

1. Micro-step execution:
- one small operation per step,
- stop after each step and verify acceptance criteria.
2. Zero silent assumptions:
- unresolved ambiguity requires user confirmation.
3. Self-Correction Rule:
- after each mutation step (edit/write/create), agent MUST run `syntax check`, `linter`, or `scripts/security-review-gate.ps1/sh`.
- fix errors immediately before moving to the next task step.
4. Stricter output contract:
- required output schema fields,
- explicit unknowns/open questions list.
4. Reliability scoring:
- evaluate tasks with `pass@k` and `pass^k` before broad rollout.

## Weak-Model Workflow (Micro-Stepping)

When a weak model is active (e.g., `gpt-oss-120b` or local model), the following **Agent-Led Dialogue** is mandatory:

### 1. Mandatory Pre-Flight Questions
The agent MUST ask the user before starting any tool-use task:
- "I am in weak-model mode. Which **single** file should I focus on for this micro-step?"
- "What is the **exact** line range or function name to modify?"
- "What is the **minimal** shell command to verify ONLY this change?"

### 2. Task Formulation (User -> Agent)
Users are encouraged to use the **Action-Context-Result** format:
`[FILE] + [PRECISE_CHANGE_DESCRIPTION] + [ACCEPTANCE_CRITERIA]`

Example:
`src/auth.ts + add "admin" to UserRoles enum + syntax check passes`

### 3. Reliability Rules (Rule 14 & 23)
- **Context Capping**: Read only 1 file per turn. No recursive `ls`.
- **Atomic Edits**: Max 30 lines of change per edit.
- **Verification Loop**: Run syntax/linter after **every single file mutation**.
- **No Refactoring**: Do not perform "cleanup" outside the requested scope.

## Activation

Use profile key from `policy/tool-permissions-profiles.json`:

- `default` for global baseline.
- `weak_model` for weak-model overlay scenarios.

Audit commands:

- PowerShell: `pwsh -NoProfile -File .\scripts\audit-permissions-policy.ps1 -ProfileName weak_model`
- Bash: `bash ./scripts/audit-permissions-policy.sh --profile-name weak_model`
