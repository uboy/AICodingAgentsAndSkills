---
name: text-cleanup
description: Clean and improve Russian text while preserving facts and original meaning.
---

# Skill: text-cleanup

## Purpose

Clean and improve Russian text while preserving meaning, facts, and author intent.

## Input

- Raw text from user.
- Optional style constraints.

## Shared Safety

Apply baseline rules from `../_shared/TEXT_GUARDRAILS.md`.

## Mandatory Rules

1. Do not change facts or claims.
2. Do not add external knowledge.
3. Remove filler, duplication, and obvious language noise.
4. Keep paragraph structure readable (avoid one-sentence-per-line style unless explicitly requested).
5. Normalize punctuation and spacing.

## Workflow

1. Detect cleanup scope:
- light cleanup (minimal edits),
- standard cleanup (default),
- deep rewrite (only if requested).
2. Apply edits in this order:
- factual safety check,
- structure and flow,
- lexical and syntax cleanup,
- typography normalization.
3. Run final check:
- no invented facts,
- no dropped core meaning,
- no leaked sensitive fragments.

## Output Format

Always return:

1. `Исправленный текст`
2. `Лог правок` (5-12 concise bullets: structure, language, typography, safety redactions if any)
