---
name: <skill-name>
description: <one-line skill summary>
---

# Skill: <skill-name>

## Purpose

One-paragraph statement of the exact user outcome this skill delivers.

## Use When

- Condition 1
- Condition 2

## Do Not Use When

- Condition A (handoff to another skill/agent)
- Condition B

## Input

- Required input fields.
- Optional constraints.

## Shared Safety

Apply baseline guardrails from `../_shared/TEXT_GUARDRAILS.md` when processing user text or transcripts.

## Workflow

1. Intake and scope check.
2. Source-grounded processing.
3. Quality and safety verification.

## Output Format

1. Section 1
2. Section 2
3. Section 3

## Self-Check

- No fabricated facts.
- Required structure is present.
- Sensitive data masked when present.

## Gotchas

Common model mistakes to watch for:

- **Section skipping**: The model skips optional sections instead of writing `not specified`. Always include all required sections.
- **Vague purpose**: The skill description in frontmatter is too generic to trigger correctly. Keep it specific with concrete action verbs.
- **Missing input contract**: The model doesn't know what input to expect. Always list required and optional input fields explicitly.
- **Safety section omission**: The model forgets to apply shared guardrails. Always reference `../_shared/TEXT_GUARDRAILS.md` or equivalent.
