# Skills

Shared reusable text skills for AI agents in this repository.

## Standards And Shared Components

- Quality baseline: `skills/QUALITY-STANDARD.md`
- New skill template: `skills/_template/SKILL.md`
- Shared guardrails for text workflows: `skills/_shared/TEXT_GUARDRAILS.md`

## Available Skills

- `text-cleanup`: constrained text editing and normalization.
- `lecture-transcript`: unified lecture transcript processing with mode-based output.
- `meeting-notes`: meeting transcript extraction into structured decisions and actions.

## Why this structure

- Reduces duplicate prompts with overlapping logic.
- Keeps one canonical rule set per task family.
- Makes outputs more predictable for automation and review.
