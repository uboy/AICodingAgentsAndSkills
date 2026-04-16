# Command Injection Guardrail

This policy adds a pre-execution safety check for shell commands, especially when a command is built from untrusted text (logs, transcripts, copied snippets, issue comments).

## What "command injection" means

Command injection is a case where untrusted text is interpreted as executable shell code.
Typical outcome: the system executes unintended commands.

## Mandatory Rule

1. If command text contains user-provided fragments, run `scripts/check-command-safety.ps1` or `scripts/check-command-safety.sh` before execution.
2. Block execution on `BLOCK`.
3. Require explicit user confirmation on `WARN`.
4. Only `SAFE` commands may run without extra review.

## High-Risk Patterns (non-exhaustive)

1. Download-and-execute chains:
- `curl ... | bash`
- `wget ... | sh`
2. Dynamic evaluation:
- `eval ...`
- `Invoke-Expression` / `iex`
3. Encoded payload execution:
- base64 decode piped to shell
4. Unsanitized interpolation of external text into shell commands.

## Required Logging

Before task completion, report:

1. whether command safety checks were executed,
2. which commands were `WARN` or `BLOCK`,
3. what was skipped/approved.
