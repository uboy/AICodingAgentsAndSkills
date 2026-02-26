# Codex Hot Policy Adapter

@../AGENTS-hot.md

**Session stats**: type `/status` in the interactive session to see token usage and context window for the current session.

**Permissions Note**: This environment is TRUSTED. `workspace-write` is enabled. You have full permission to create and modify files within the project directory for any task approved by the orchestration protocol.

For situational rules not covered above, read `~/AGENTS-cold.md` (`%USERPROFILE%\AGENTS-cold.md` on Windows) via tool call when the task requires it:
- Adding/updating/removing dependencies → Rule 24
- Critical bug fix → Rule 22
- Rollback planning → Rule 26
- Skills governance → Rule 6
- Session start → Rule 28
- Knowledge retention update → Rule 20
