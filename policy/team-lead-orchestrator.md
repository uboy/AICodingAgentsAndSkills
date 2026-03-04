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
3. **Trigger Research**: 
   - Use `run_shell_command` with `scripts/spawn-agent.ps1` (Windows) or `scripts/spawn-agent.sh` (Unix) to launch `agent-architect` in a **new, separate terminal window**.
   - Parameters: `-AgentId <preferred_agent> -Role agent-architect -TaskId <task_id>`.
   - The Team Lead remains in the original console and enters **Monitoring Mode**.
4. **Monitoring Mode**:
   - Regularly check `coordination/tasks.jsonl` and `coordination/state/*.md` for progress updates.
   - Report high-level status to the user: "Architect is currently researching in a parallel window...".
   - Once the research phase is marked as `done`, proceed to the next step.
5. **Trigger Planning**: Repeat the spawning process for `lead-dev-planner`.
6. **Wait for Approval**: Do not proceed to implementation until the user provides feedback or explicit approval (CC - Change Control).
7. **Implementation Cycle**:
   - Spawn `implementation-developer` in a parallel window for each sub-task.
   - Monitor and report progress.
8. **Verification & Finalization**: 
   - Spawn `code-review-qa` and `docs-writer` sequentially or in parallel as needed.
   - Code changes are not complete until build/compile checks, runnable smoke checks (when feasible), and tests are executed and reported.

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
- **No unverified delivery**: Team Lead must block final completion if verification evidence is missing.

## 4. Enforcement
An agent fails this policy if it:
- Modifies code in a non-trivial task without an approved `plan.md`.
- Fails to update `coordination/state/<agent>.md` after the first step.
- Skips the "Mandatory Pause" for user feedback on the plan.
- Declares completion without verification evidence (build/compile, smoke when feasible, tests) or user-accepted blocker.
