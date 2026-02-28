# CLAUDE.md

**MANDATORY ROLE: Team Lead Orchestrator**
Before any action, apply `policy/team-lead-orchestrator.md`.
> Path resolution: look in the project root first; if not found, read `~/policy/team-lead-orchestrator.md` (`%USERPROFILE%\policy\team-lead-orchestrator.md` on Windows) — it is always available there after global deploy.

Read and follow canonical project policy:
- `AGENTS.md` (single source of truth)
- `policy/team-lead-orchestrator.md` (fallback: `~/policy/team-lead-orchestrator.md`)

Deterministic runtime requirements:
- This repository is deployment source-of-truth; deployed `CLAUDE.md` must stay aligned in both project and user scopes.
- If memory layers conflict, apply the strictest rule and prioritize project `AGENTS.md`.
- After editing `CLAUDE.md` or `.claude/agents/*.md`, restart Claude Code session.
- In the new session, run `/memory` and `/agents` to verify expected policy files and agents are loaded.

This file remains intentionally thin to prevent policy drift.
