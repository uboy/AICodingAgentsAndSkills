# Handoff

## Task

- ID: T-20260305-auto-orchestration
- Owner: gemini

## Summary

- Implemented `scripts/spawn-agent.ps1` and `.sh` for cross-OS parallel agent launching.
- Refactored `scripts/generate-task.ps1` and `.sh` to support non-interactive parameter passing, preventing hangs during agent execution.
- Updated `policy/team-lead-orchestrator.md` to mandate parallel spawning for non-trivial tasks.
- Team Lead now enters "Monitoring Mode" after spawning sub-agents.

## Files Touched

- scripts/spawn-agent.ps1
- scripts/spawn-agent.sh
- scripts/generate-task.ps1
- scripts/generate-task.sh
- policy/team-lead-orchestrator.md
- coordination/cycle-contract.json
- coordination/change-scope.txt
- coordination/reviews/T-20260305-auto-orchestration.md

## Verification

- `pwsh -NoProfile -File .\scripts\spawn-agent.ps1 -AgentId codex -Role test -TaskId T-TEST -DryRun` -> pass.
- Full validation pipeline (skills, review, cycle, security) passes.

## Commit Message

feat(orchestration): implement auto-spawning of parallel agents

- Add cross-OS scripts/spawn-agent for programmatic terminal launching.
- Update Team Lead policy to mandate parallel execution for non-trivial tasks.
- Refine coordination artifacts and cycle contract for autonomous workflows.
