# Homework Processing Base Rules (Shared)

Mandatory baseline for any skill that produces academic homework content.

Shared source-handling contract:
- `ACADEMIC_SOURCE_PACK.md`

## Source Grounding

1. All claims MUST be traceable to provided sources.
2. Do not add external facts, references, or examples not present in sources.
3. If a fact cannot be cited, explicitly flag it as `источник не указан`.
4. When source is ambiguous or ASR quality is poor, mark as `требует уточнения`.

## Citation Requirements

1. Every key claim requires citation.
2. Citation formats:
   - Lecture transcript: `[Лекция N, ЧЧ:ММ:СС]` (with timestamp)
   - Lecture slides: `[Лекция N, слайд M]`
   - Presentation: `[Презентация «Название», слайд N]`
   - Document: `[Документ «Название», стр. N]` or section reference
   - Book: `[Автор, «Название», стр. N]`
   - Video: `[Видео «Название», ЧЧ:ММ:СС]` or `требует просмотра`
3. Citation modes:
   - `inline`: citations in text flow (default)
   - `footnote`: numbered references at end of document

## Academic Context

1. Target: management program (2-year Master's course)
2. Subjects supported (extensible):
   - HR-менеджмент
   - Автоматизация бизнес-процессов
   - Маркетинговые стратегии
   - Управление бизнес-процессами
   - Управление проектами
   - Стратегический менеджмент
   - Финансовый менеджмент
   - Цифровая трансформация бизнеса
   - Правовые аспекты бизнеса
   - Коммуникации в организации
   - (and others as they appear)
3. Tone: professional academic Russian
4. Style: clear, structured, suitable for university submission

## Source Handling

Use `ACADEMIC_SOURCE_PACK.md` as the canonical contract for:
- prepared Markdown source packs,
- acceptable raw source forms,
- when source preparation is recommended,
- and what academic skills may or may not assume about extracted materials.

## Integrity Rules

1. Preserve factual accuracy from sources.
2. Do not invent statistics, dates, names, or quotes.
3. Do not extrapolate beyond what sources explicitly state.
4. Mark uncertain content as `требует уточнения`.
5. Separate facts from interpretations clearly.
6. When sources conflict, note the discrepancy.

## Output Quality

1. Structure must match the requested homework format (essay, case, presentation).
2. Language must be academically appropriate Russian.
3. Avoid AI-typical patterns (will be cleaned by text-humanize if needed).
4. Include complete source list at the end.
5. Flag any gaps where required content was not found in sources.

## Integration with Other Skills

- Use `lecture-transcript` to process raw transcripts before homework generation.
- Use `text-humanize` as optional post-processor for natural language output.
- `homework-manager` may call the `homework-indexer` agent when source discovery or packet assembly is needed before `homework-management`.
