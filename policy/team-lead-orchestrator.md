# Team Lead Orchestrator Policy

This policy governs the first hop of every top-level agent (Gemini, Claude, Codex, Cursor, OpenCode, etc.) when a user sends a request.

## 1. First Gate: Classify Before Doing

Before loading skills, lifecycle rules, or a final response contract, the agent MUST classify:

- **task size**: `trivial` or `non_trivial`
- **task profile**: `repo_change`, `repo_read`, `content_task`, or `general`

Use `policy/task-routing-matrix.json` as the compact source of truth.

Before delegation or multi-step execution, the orchestrator MUST also create or refresh an execution brief following `policy/execution-brief-contract.md`.

## 2. Profile Routing

### `repo_change`

Use when the user wants tracked repository files changed.

- **Trivial**:
  1. Explain what will be changed.
  2. Execute directly.
  3. Verify and report.
- **Non-trivial**:
  1. **HALT implementation.**
  2. State clearly: "This is a non-trivial repo-change task — following the 6-step lifecycle per project policy."
  3. Produce or refresh an execution brief before downstream delegation.
  4. Produce `research.md` and `plan.md`.
  5. Pause for user CC.
  6. Maintain a local checklist/task tracker.
  7. Implement, verify, review, and document in narrow verified chunks.
  8. Use the local multi-agent workflow when enabled; otherwise execute the same phases sequentially in the current session.

### `repo_read`

Use when the user wants codebase analysis, explanation, audit, or review without asking for repository edits.

- Keep the task read-only by default.
- Use review and analysis skills only.
- A short analysis plan is allowed for larger investigations.
- Do not emit repo/git delivery tail unless the task is explicitly reclassified to `repo_change`.

### `content_task`

Use when the task is about homework, transcripts, notes, source analysis, rewriting, or other content-first work.

- Load only content/text/homework agents and skills.
- Refine the raw user request into an execution brief before delegating multi-step content work.
- For multi-step tasks, create:
  1. an **Execution Brief**
  2. an **Execution Plan**
  3. an **Answer Plan**
- Work sequentially in small steps instead of jumping straight to a final answer.
- Use silent final cleanup or humanization when the selected content workflow requires it.
- Repo/git delivery tail is forbidden.

### `general`

Use when the user is asking about policy, process, behavior, or needs a lightweight answer.

- Answer directly or ask one focused clarification question.
- Do not load heavyweight repo-change workflow unless the request is reclassified.
- Repo/git delivery tail is forbidden.

## 3. Global Guardrails

- **Context first**: run the startup ritual before work.
- **Refine before delegate**: do not forward raw user wording unchanged when the next agent or skill would benefit from a tighter execution brief.
- **No shadow work**: do not make hidden tracked-repo changes before the selected workflow permits them.
- **Clarification**: if the request is underspecified and the ambiguity changes routing or output materially, ask one focused clarifying question.
- **Rule refresh**: for long tasks, refresh the active brief and chunk boundary before the next execution chunk or delegation hop.
- **No unverified delivery**: block final completion when required verification is missing.
- **User language**: answer in the user's language unless a concrete artifact must stay in another language.

## 4. Commit-Output Gate

`Commit Message` is allowed only when:

- the active profile is `repo_change`;
- the task produced a real tracked repo diff;
- required verification passed;
- no known secret, scope, or failed-gate blockers remain;
- and the change is genuinely ready for a normal commit.

If that gate does not pass, omit commit-output blocks in ordinary user-facing answers.

## 5. Enforcement

An agent fails this policy if it:

- skips task-profile classification before routing;
- applies the repo-change lifecycle to content/general work by default;
- emits repo/git delivery tail for `content_task` or `general`;
- modifies tracked repo files in a non-trivial `repo_change` task without an approved `plan.md`;
- declares completion without verification evidence or a user-accepted blocker.
