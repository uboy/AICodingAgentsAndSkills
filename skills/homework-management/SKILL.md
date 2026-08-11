---
name: homework-management
description: Produce source-grounded academic homework support from provided materials without fabricating claims.
---

# Skill: homework-management

## Purpose

Help the user complete academic homework in a source-grounded way that supports learning rather than blind answer dumping.

This skill is for:
- planning an answer,
- structuring an essay or case response,
- drafting source-grounded academic text,
- comparing positions from provided materials,
- producing short supported answers.

It is not a generic tutor and not a free-form content generator.

## Use When

- The user has an assignment, question, or academic prompt plus source materials.
- The user wants help turning lectures, notes, slides, or documents into a structured academic answer.
- The user needs explicit citation discipline or source traceability.
- The user needs help identifying missing evidence before writing.

## Do Not Use When

- The user only has a raw lecture transcript and first needs study materials: use `lecture-transcript`.
- The user needs structured case reasoning with explicit options, trade-offs, and evidence gaps: use `case-analyzer`.
- The user wants broad tutoring without sources.
- The user wants a thesis-scale workflow or long research project support.
- The user asks for unsourced live-test answers or fabricated evidence.
- The user needs legal, medical, or other domain-expert advice beyond provided materials.

## Input

- `mode`: one of `essay`, `business_case`, `short_answer`, `comparison`, `answer_plan`.
- `task`: assignment prompt, question, or topic.
- `sources`: provided materials, excerpts, or clearly enumerated source list.
- Optional:
  - `citation_mode`: `inline` or `footnote`
  - `word_limit`
  - `language`
  - `learning_goal`
  - `required_sections`

If `mode` is omitted, default to `answer_plan`.

## Preferred Source Forms

Apply the shared source-handling contract from `../_shared/ACADEMIC_SOURCE_PACK.md`.

Preferred:
- prepared Markdown source packs produced by `scripts/study-materials-prep.py`,
- curated lecture-derived notes,
- structured excerpts with traceable origin.

Also supported:
- directly provided lecture notes, slides, document excerpts, or short source bundles.

Prep recommendation:
- recommended for multi-source assignments, scanned material sets, archive-based materials, or reused study collections;
- optional for small, already curated source sets.

Prepared-source trust model:
- prefer `prepared_trusted` Markdown files for the main working context;
- if a prepared file is marked `review_needed`, use it for orientation, gap detection, or provisional structure, but check `originals/` before relying on it for citations, quotations, numbers, or decisive claims;
- use merged packs for broad context loading, then drill into source members or originals for exact support.

## Shared Safety

Apply the baseline from `../_shared/HOMEWORK_BASE.md`.

## Safety Rules

1. Every substantive claim must be traceable to the provided sources.
2. If evidence is missing, say so explicitly instead of inventing content.
3. Distinguish facts from interpretation and recommendations.
4. Refuse to simulate unseen sources, unread books, or unprovided lectures.
5. If the user asks for direct test cheating or unsupported answer generation, redirect to a study-oriented plan or source-based explanation.
6. If the provided source set is too weak for the requested answer, downgrade to planning, gap analysis, or a partial draft instead of inventing support.
7. If the available prepared materials are flagged `review_needed`, treat original files as fallback evidence for critical support.

## Mode Contracts

### `answer_plan`

Output:

1. `## Что требует ответ`
2. `## Какие источники использовать`
3. `## Рабочий тезис или позиция`
4. `## План ответа`
5. `## Где не хватает доказательств`
6. `## Что понять перед сдачей`

Use when source coverage is partial or the user wants planning before drafting.

### `essay`

Output:

1. `## Тезис`
2. `## План`
3. `## Черновик эссе`
4. `## Источники и ссылки`
5. `## Что требует уточнения`
6. `## Что стоит повторить по теме`

Requirements:
- argument must stay tied to sources;
- citations must appear for every key claim;
- if the sources do not support a full essay, downgrade to a partial draft and call out the gap.

### `business_case`

Output:

1. `## Ситуация`
2. `## Факты из кейса и материалов`
3. `## Основные проблемы`
4. `## Анализ причин`
5. `## Варианты действий`
6. `## Рекомендуемое решение`
7. `## Ограничения и пробелы в доказательствах`
8. `## Источники`

Requirements:
- separate case facts from interpretation;
- tie recommendations to both case evidence and provided theory.

### `short_answer`

Output:

1. `## Краткий ответ`
2. `## Поддерживающие пункты`
3. `## Ссылки на источники`
4. `## Что осталось неясным`

Requirements:
- concise answer first;
- only essential support points;
- no generic filler.

### `comparison`

Output:

1. `## Объекты сравнения`
2. `## Критерии`
3. `## Сравнение по критериям`
4. `## Вывод`
5. `## Источники`
6. `## Где сравнение остаётся неполным`

Requirements:
- compare only what the provided materials support;
- if one side is under-sourced, flag imbalance clearly.

## Workflow

1. Identify the requested homework shape and choose the mode.
2. Check whether the provided sources are sufficient for the requested output.
3. Extract claims, evidence, quotes, and contradictions from the materials.
4. Build a source-grounded structure before writing prose.
5. Produce the answer in the selected mode.
6. End with gaps, uncertainty, and a short learning-oriented recap.

## Final Validation Checklist

- Every key claim is source-grounded.
- Output matches the selected mode.
- Missing evidence is flagged explicitly.
- No unsupported external facts or references were introduced.
- The result helps the user understand the material, not just submit text blindly.
