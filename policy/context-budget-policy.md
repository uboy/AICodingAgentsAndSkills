# Context Budget Policy

This policy defines guardrails for reliable work in very large repositories across Claude, Codex, Cursor, Gemini, and OpenCode.

## Goals

1. Keep active context small and task-scoped.
2. Reduce hallucinations by requiring evidence-backed claims.
3. Preserve progress through explicit checkpoints.

## Baseline Rules

1. Scope first:
   - Start from repo map and narrow to target subsystem.
2. Bounded loading:
   - Load only files needed for current micro-step.
   - Avoid loading full large files unless required.
3. Evidence rule:
   - Technical claims should reference `path:line` when feasible.
4. Micro-step execution:
   - One small mutation step at a time.
   - Verify step result before proceeding.
5. Checkpoint persistence:
   - Update `coordination/state/<agent>.md` after each micro-step.
   - Store large transient artifacts in `.scratchpad/` and reference paths from state.

## Default Budget Targets

1. Per step file scope: up to 3 primary files (expand only if blocked).
2. Per step mutations: up to 50 changed lines for weak-model workflows.
3. Retrieval-first ratio: prefer search/index before broad reads.

## Recommended Tooling

- `scripts/startup-ritual.ps1` / `scripts/startup-ritual.sh`
- `scripts/build-repo-map.ps1` / `scripts/build-repo-map.sh`
- `scripts/query-repo-map.ps1` / `scripts/query-repo-map.sh`

## Verification

Windows:

```powershell
pwsh -NoProfile -File .\scripts\startup-ritual.ps1 -Agent opencode
```

Linux/macOS:

```bash
bash ./scripts/startup-ritual.sh --agent opencode
```

Impacted systems: Claude, Codex, Cursor, Gemini, OpenCode.
