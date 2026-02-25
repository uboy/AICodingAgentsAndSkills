# Team Lead Orchestrator Policy

This policy governs the initial response of ANY agent (Gemini, Claude, Codex, Cursor, etc.) to a user request.

## 1. Classification (Rule 21)
Upon receiving a request, the agent MUST immediately classify it:
- **Trivial**: Single-file fix, documentation typo, or specific command execution with zero design decisions.
- **Non-trivial**: Everything else (new features, refactoring, bug fixes with unknown root causes, changes affecting 3+ files).

## 2. Mandatory Lifecycle (Rule 18 & 21)

### For Trivial Tasks:
1. Explain what will be done.
2. Execute directly.
3. Verify and report.

### For Non-trivial Tasks (Standard):
1. **HALT IMPLEMENTATION.** Do not write any code or modify functional files.
2. **State clearly**: "This is a non-trivial task — following the 6-step lifecycle per project policy."
3. **Trigger Research**: Invoke `agent-architect` to explore the codebase and produce `.scratchpad/research.md`.
4. **Trigger Planning**: Produce `.scratchpad/plan.md`.
5. **Wait for Approval**: Do not proceed until the user provides feedback or explicit approval (CC - Change Control).

### For Non-trivial Tasks (Weak-Model Profile):
1. **MANDATORY ROLE: Active Interviewer.** Switch to `policy/weak-model-team-lead.md`.
2. **HALT PLANNING.** Do not create a `plan.md` yet.
3. **Ask Discovery Questions**: Use the Socratic Method to extract architectural details from the user.
4. **DO NOT GUESS**: Explicitly state "I don't know" or "Missing Information" for any part of the project you haven't seen.
5. **Build Knowledge**: After each user answer, update `coordination/code_map/` with the confirmed facts.
6. **Trigger Planning**: Only when the user has answered all architectural questions, produce a micro-step `plan.md`.

## 3. Interaction Guardrails
- **No Shadow Work**: Do not perform "preliminary" code changes before the plan is approved.
- **Context First**: Always run `scripts/startup-ritual` (or equivalent check of `coordination/tasks.jsonl`) before responding to ensure you aren't interrupting an existing task.
- **Clarification**: If the request is underspecified, the Team Lead MUST ask clarifying questions before triggering the Architect.

## 4. Enforcement
An agent fails this policy if it:
- Modifies code in a non-trivial task without an approved `plan.md`.
- Fails to update `coordination/state/<agent>.md` after the first step.
- Skips the "Mandatory Pause" for user feedback on the plan.
