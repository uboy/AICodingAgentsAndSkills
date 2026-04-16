---
name: build-system-analysis
description: Analyze complex multi-tool build systems and produce actionable build topology and change plans.
---

# Skill: build-system-analysis

## Purpose

Help users understand large and mixed build stacks (shell, Ninja, GN, Python, npm, and related tooling), trace target lineage, and produce safe steps for adding or changing build targets.

## Use When

- The repository has multiple build entrypoints and generated steps.
- You need to document how artifacts are produced end-to-end.
- You need a low-risk recipe to add a new target or modify build behavior.

## Do Not Use When

- The task is a tiny one-file command fix with no build graph impact.
- The user asks for legal/license analysis (use legal workflow only on explicit request).

## Input

- Repository root or subsystem path.
- Target/platform scope (optional): `windows`, `linux`, `macos`, `all`.
- Desired change (optional): new target, modified flags, toolchain swap, packaging change.

## Shared Safety

Apply baseline guardrails from `../_shared/TEXT_GUARDRAILS.md` when processing external logs or copied config text.

## Workflow

1. Discover build entrypoints and orchestration files.
2. Classify build systems in use (GN/Ninja/CMake/Make/npm/Python/shell/custom).
3. Build a dependency and execution topology from entrypoint to artifact.
4. Trace requested target(s): where declared, generated, and executed.
5. Propose change plan with rollback and verification commands.
6. Produce concise docs that map "what triggers what" and "where to edit".

## Mandatory Persistence (Rule 28)

1. **Continuous Save**: Save intermediate findings (build graphs, dependency lists, command traces) to `.scratchpad/build_analysis_<timestamp>.md` **after every discovery step**.
2. **State Update**: Update `coordination/state/<agent>.md` with the path to these findings immediately.
3. **Knowledge Retention**: If you find a new build pattern, a recurring failure, or a complex dependency relationship, you MUST record it in `.agent-memory/` before finishing the task (Rule 20).

## Output Format

1. **Build Systems Detected**
   - table: `system | key files | role`
2. **Execution Topology**
   - ordered path: `entrypoint -> generators -> executors -> artifacts`
3. **Target Lineage**
   - per target: `declaration -> expansion -> execution -> output`
4. **Change Recipe**
   - exact files to edit
   - expected side effects
   - rollback steps
5. **Verification Plan**
   - Windows command
   - Linux/macOS command
6. **Open Risks**
   - cache invalidation, platform drift, non-hermetic steps, hidden generated files

## Self-Check

- Every claim references concrete files or command output.
- Output distinguishes facts vs assumptions.
- Change recipe includes rollback and cross-platform verification commands.
