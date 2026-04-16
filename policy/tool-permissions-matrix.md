# Tool Permissions Matrix

This matrix defines default operation classes for local development agents.
It is platform-agnostic and should be applied consistently for Claude, Codex, Cursor, Gemini, and OpenCode adapters.

## Policy Inputs

- If project is under git: edits inside current project directory are allowed without extra confirmation.
- If project is not under version control: every file change requires explicit user confirmation.
- Non-mutating actions in project directory (read/list/search/diff/status) should not require extra confirmation.

## Operation Classes

| Class | Examples | Default |
| --- | --- | --- |
| Read-only local | `cat`, `rg`, `ls`, `git status`, parse/lint read mode | Allow |
| Local edits in repo | create/update/delete files under project root when git repo detected | Allow |
| Local edits outside project | writing to home/system paths outside active project | Ask |
| Destructive VCS ops | `git reset --hard`, forced checkout, history rewrite | Ask |
| Network egress | external API calls, remote uploads | Ask |
| Dependency install | package manager operations changing system/project | Ask |
| Secrets operations | printing or exporting secret values | Deny by default |

## Secret Handling Controls

1. Pre-commit secret scan must be enabled.
2. Redact secrets in generated docs and logs.
3. Block commits if high-confidence secret patterns are detected.
4. Prefer placeholders in examples (`<TOKEN>`, `<SECRET>`).

## Review Gate

Before completion, agents should confirm:

1. Requested action matched class policy.
2. No unauthorized outside-project writes occurred.
3. Secret checks were executed and passed (or blocker reported).

## Enforcement

Audit/apply scripts:

- `scripts/audit-permissions-policy.ps1`
- `scripts/audit-permissions-policy.sh`

Profile source:

- `policy/tool-permissions-profiles.json`
