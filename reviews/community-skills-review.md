# Community Skills Review (VoltAgent + Ecosystem)

## Reviewed Sources

1. VoltAgent docs: https://voltagent.dev/
2. VoltAgent GitHub: https://github.com/VoltAgent/voltagent
3. Awesome Claude Code subagents list: https://github.com/hesreallyhim/awesome-claude-code-subagents
4. OpenAI security skill: https://raw.githubusercontent.com/openai/skills/main/skills/.curated/security-best-practices/SKILL.md
5. Anthropic subagent template: https://raw.githubusercontent.com/anthropics/claude-code/main/.claude/commands/setup-creating-subagents.md
6. Trail of Bits clarification-first skill: https://raw.githubusercontent.com/trailofbits/claude-code-skills/main/ask-questions-if-underspecified/SKILL.md

## Useful Ideas Found

1. Strong template discipline for skills/subagents.
2. Security defaults as first-class skill behavior, not optional add-ons.
3. Clarification-first policy for underspecified tasks.
4. Lightweight repeatable eval cases to prevent silent skill drift.
5. Operational focus on production readiness (observability/process rigor).

## Applied In This Repository

1. Added skill quality baseline: `skills/QUALITY-STANDARD.md`.
2. Added reusable template: `skills/_template/SKILL.md`.
3. Added shared text guardrails: `skills/_shared/TEXT_GUARDRAILS.md`.
4. Added permissions matrix: `policy/tool-permissions-matrix.md`.
5. Added validation scripts and eval baselines:
- `scripts/validate-skills.ps1`
- `scripts/validate-skills.sh`
- `evals/skills/README.md`
- `evals/skills/cases/*.md`

## Recommended Next (Optional)

1. Add CI job to run skill validators on every PR.
2. Add red-team prompt-injection eval cases for each text skill.
3. Add numeric scoring rubric (schema compliance, grounding, safety).
