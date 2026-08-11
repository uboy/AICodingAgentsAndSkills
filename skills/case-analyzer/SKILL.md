---
name: case-analyzer
description: Analyze source-grounded academic cases and scenario packets by separating facts, assumptions, options, and evidence gaps.
---

# Skill: case-analyzer

## Purpose

Help the learner reason through a case, scenario, or decision situation using provided source materials.

This skill is for:
- identifying the core issue or decision point,
- separating source-backed facts from assumptions and unknowns,
- comparing plausible options,
- analyzing trade-offs,
- explaining what conclusion is supported and what is not.

This skill is not a generic essay writer and not a general tutoring assistant.

## Use When

- The user has a case packet, scenario description, or decision problem with source materials.
- The user needs structured reasoning about alternatives, risks, or evidence quality.
- The user wants to understand how to think through a case before writing a full assignment.
- The materials are already prepared as Markdown packets, lecture-derived notes, or structured excerpts.

## Do Not Use When

- The user needs raw transcript processing into study materials: use `lecture-transcript`.
- The user needs a broader assignment draft or essay built from multiple materials: use `homework-management`.
- The user wants free-form tutoring without source material.
- The user asks for a strong decision or conclusion that the sources do not support.
- The task is a long-form thesis or research workflow rather than a bounded case.

## Input

- `mode`: one of `case_brief`, `issue_map`, `options_analysis`, `recommendation`, `evidence_gaps`.
- `case_materials`: case description, scenario packet, prepared Markdown source files, lecture-derived notes, or direct excerpts.
- Optional:
  - `question`: assignment framing or discussion question
  - `decision_focus`: decision to evaluate
  - `supporting_sources`: additional excerpts, notes, or readings
  - `language`

If `mode` is omitted, default to `issue_map`.

## Preferred Source Forms

Apply the shared source-handling contract from `../_shared/ACADEMIC_SOURCE_PACK.md`.

Preferred:
- prepared Markdown outputs from `scripts/study-materials-prep.py`
- lecture-derived notes from `lecture-transcript`
- structured case packets or source excerpts with headings and evidence sections

Also supported:
- directly provided case text
- short scenario descriptions plus supporting evidence excerpts

Not required:
- the prep pipeline is preferred, but this skill must still work on direct source material if it is reasonably structured.

Prep recommendation:
- recommended for multi-document cases, archive-based packets, scanned material sets, or scenarios where evidence is split across several files;
- optional for one short case text plus direct supporting excerpts.

Prepared-source trust model:
- prefer `prepared_trusted` case packets and supporting Markdown files;
- if the prep output is marked `review_needed`, use it to map issues and options, but fall back to `originals/` before treating fine-grained facts or quotations as settled;
- use merged packs for first-pass overview when a case packet was fragmented across many small files.

## Shared Safety

Apply the baseline from `../_shared/HOMEWORK_BASE.md`.

## Grounding Rules

1. Separate three things clearly:
   - source-backed facts,
   - interpretation or inference,
   - unknowns or missing evidence.
2. Never present an inference as if it were directly stated in the sources.
3. Do not import outside knowledge unless the user explicitly asks for external context, and then label it as external.
4. If multiple interpretations are plausible, compare them instead of pretending one is certain.
5. Prefer `недостаточно данных` over an unsupported recommendation.
6. If prepared materials are flagged `review_needed`, say where the original file should be checked before trusting a decisive case conclusion.

## Uncertainty Rules

1. Mark weakly supported claims as `слабая опора в источниках`.
2. Mark missing but decision-critical evidence as `нужно дополнительное подтверждение`.
3. If the case packet omits a key stakeholder, metric, or constraint, call that out explicitly.

## Mode Contracts

### `case_brief`

Output:

1. `## Ситуация`
2. `## Ключевой вопрос`
3. `## Факты из источников`
4. `## Ограничения и неизвестное`
5. `## Что важно понять перед обсуждением`

Use when the learner first needs a compact, source-grounded picture of the case.

### `issue_map`

Output:

1. `## Центральная проблема`
2. `## Подвопросы`
3. `## Факты`
4. `## Предположения`
5. `## Неизвестное`
6. `## Какие источники поддерживают каждый пункт`

Use when the learner needs to disentangle the case structure before choosing a position.

### `options_analysis`

Output:

1. `## Возможные варианты`
2. `## Потенциальные плюсы`
3. `## Потенциальные риски`
4. `## На чём основан каждый вывод`
5. `## Где доказательства слабые`

Requirements:
- compare at least two plausible options when the case allows it;
- do not invent options unsupported by the scenario.

### `recommendation`

Output:

1. `## Рекомендуемый ход`
2. `## Почему это поддерживается источниками`
3. `## Альтернативы`
4. `## Что может изменить рекомендацию`
5. `## Где вывод остаётся условным`

Requirements:
- recommendation must be explicitly conditional on available evidence;
- if evidence is insufficient, say so and downgrade the conclusion.

### `evidence_gaps`

Output:

1. `## Что уже известно`
2. `## Чего не хватает`
3. `## Почему это критично`
4. `## Что стоит проверить дальше`

Use when the learner or instructor needs to understand why a confident answer is not yet justified.

## Workflow

1. Identify the case question and choose the right mode.
2. Extract the source-backed facts first.
3. Separate assumptions, interpretations, and unknowns.
4. Build a structured reasoning view of options or issues.
5. Produce the mode-specific output.
6. End with uncertainty and evidence gaps where needed.

## Final Validation Checklist

- Facts are separated from inference.
- Unsupported conclusions are not presented as settled.
- Missing evidence is surfaced explicitly.
- The selected mode contract is followed.
- The output helps the learner understand the reasoning process, not just the final answer.
