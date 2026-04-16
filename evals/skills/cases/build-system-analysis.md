# Eval Case: build-system-analysis

## Input Scenario

Monorepo uses GN + Ninja + shell wrappers + Python generation scripts + npm packaging; user asks how to add a new target and document build flow.

## Acceptance Checks

1. Build topology lists entrypoint to final artifact chain.
2. Target lineage includes declaration, generation, and execution points.
3. Output includes rollback and cross-platform verification commands.
