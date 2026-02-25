# Skills

Shared reusable skills for AI agents in this repository.

## Standards And Shared Components

- Quality baseline: `skills/QUALITY-STANDARD.md`
- New skill template: `skills/_template/SKILL.md`
- Shared guardrails for text workflows: `skills/_shared/TEXT_GUARDRAILS.md`

## Available Skills

- `text-cleanup`: constrained text editing and normalization.
- `lecture-transcript`: unified lecture transcript processing with mode-based output.
- `meeting-notes`: meeting transcript extraction into structured decisions and actions.
- `code-review`: generic PR/commit/local code review workflow with severity-based findings.
- `android-code-review`: Android-focused review for correctness, lifecycle safety, performance, security, and tests.
- `ios-code-review`: iOS-focused review for correctness, lifecycle safety, performance, security, and tests.
- `java-code-review`: Java-focused review for correctness, concurrency safety, performance, security, and tests.
- `performance-review`: performance-focused review for regressions, bottlenecks, and scalability risks.
- `security-review`: security-focused review for vulnerabilities, trust boundaries, and secret handling.
- `ci-failure-debugger`: root-cause analysis workflow for CI failures with minimal fix plans.
- `api-contract-review`: API compatibility and schema contract review.
- `build-system-analysis`: analyze large multi-tool build pipelines and produce target-change recipes.
- `large-codebase-context`: context-budgeted workflow for reliable work in very large repositories.

## Why this structure

- Reduces duplicate prompts with overlapping logic.
- Keeps one canonical rule set per task family.
- Makes outputs more predictable for automation and review.
