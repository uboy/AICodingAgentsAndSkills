---
name: text-humanize
description: Rewrite AI-generated Russian text to sound natural and human, removing template patterns.
---

# Skill: text-humanize

## Purpose

Transform AI-generated or overly formal Russian text into natural, human-sounding prose while preserving meaning, logic, and factual content.

## Use When

- User has AI-generated text that sounds robotic or template-like
- User wants to remove formulaic constructions typical of neural network output
- User needs text to pass as naturally written by a competent human
- User asks to "humanize", "make natural", "remove AI patterns" from text

## Do Not Use When

- User needs factual cleanup or error correction (use text-cleanup skill)
- User needs translation between languages
- User needs content generation (use homework-management or other content skills)
- Text is already natural and human-sounding

## Input

- Text to humanize (Russian)
- Optional: `preserve_citations` (default: true) — keep citation markers `[Лекция N, ЧЧ:ММ]` intact
- Optional: `formality_level`: `academic` (default) | `business` | `casual`
- Optional: `domain_context` — subject area for terminology preservation

## Shared Safety

Apply baseline rules from `../_shared/TEXT_GUARDRAILS.md`.

## Core Priority

**Preserve meaning and logic first.** Then remove bureaucratic language, template correctness, and artificial smoothness. If a formal rule conflicts with meaning or author intent, preserve meaning.

## Forbidden Patterns (MUST REMOVE)

### Structural Patterns

1. **Контрастные конструкции**:
   - `не X, а Y` — rewrite without contrast structure
   - `это не просто X, а...` — remove completely, state directly

2. **Симметричные предложения**:
   - Balanced parallel structures that sound artificial
   - Mirror-like sentence pairs

3. **Лестничная запись**:
   - Step-ladder enumeration of obvious progressions
   - Single-sentence paragraphs without semantic reason
   - Pseudo-dramatic line breaks

4. **Рваные конструкции с повтором**:
   - `Без восторгов. Без лишних слов.` — combine or rewrite

### Forbidden Phrases (remove or rephrase)

- `важно понимать`
- `стоит отметить`
- `необходимо подчеркнуть`
- `следует отметить`
- `в современном мире`
- `в настоящее время`
- `таким образом`
- `в конечном итоге`
- `как известно`
- `очевидно, что`
- `следует учитывать`

### Anglicism Rules

- **REMOVE** unnecessary anglicisms when Russian equivalent is natural and precise
- **KEEP** domain terms: HR, KPI, ROI, CRM, API, etc.
- **KEEP** natural speech of business/tech environment
- **REPLACE** office jargon: `апдейт` → `обновление`, `имплементация` → `внедрение`, `фидбек` → `отзыв`, `юзать` → `использовать`
- When in doubt, prefer clarity over aggressive purism
- Text should not sound "forcibly purified"

## Typography Rules

1. **Dash**: use en-dash `–` (U+2013), NOT em-dash `—` (U+2014)
   - Correct: `Управление персоналом – ключевая функция`
   - Wrong: `Управление персоналом — ключевая функция`

2. **Quotes**: use Russian guillemets `«»`
   - Correct: `термин «компетенция»`
   - Wrong: `термин "компетенция"` or `термин 'компетенция'`
   - Nested quotes: `«внешние «ёлочки»»` (not English style)

3. **Hyphen vs dash**:
   - Hyphen `-` inside words: `бизнес-процесс`
   - En-dash `–` between sentence parts

4. **Spacing**: single space after punctuation, no decorative punctuation overload

## Metaphor Limit

**Maximum 2 metaphors per text.** Remove excess, especially:
- Clichés: `стержень`, `краеугольный камень`, `фундамент`, `двигатель`
- Mixed metaphors
- Chains of metaphors

## Transformation Guidelines

1. Simplify without losing precision
2. Prefer active voice over passive constructions
3. Prefer concrete nouns over abstract nominalizations
4. Break long sentences into shorter ones (varied rhythm)
5. Remove hedging language unless uncertainty is factual
6. Keep technical accuracy in domain terms
7. Make neighboring paragraphs differ in length and rhythm
8. Ground each statement with fact, detail, observation, cause, or consequence

## Workflow

1. **Analyze** — identify AI markers, template patterns, forbidden phrases
2. **Transform** — rewrite preserving meaning, removing forbidden patterns
3. **Typography** — normalize dashes, quotes, spacing
4. **Verify** — check metaphor count, citation preservation, meaning integrity
5. **Report** — list what was changed (3-5 bullet points)

## Output Format

Always return exactly two sections:

### 1. Исправленный текст

[The humanized text with all transformations applied]

### 2. Что исправлено

[3-5 concise bullet points describing changes made]

**Example output:**
```
### Исправленный текст

Компетентностный подход стал основой HR-практик в большинстве крупных компаний. Когда компания понимает, какие навыки нужны на каждой позиции, подбор и оценка персонала становятся предсказуемыми [Лекция 2, 15:30]. Без чёткой модели компетенций рекрутеры полагаются на интуицию – и ошибаются в половине случаев [Лекция 2, 18:45].

### Что исправлено

- Убраны конструкции «не X, а Y» (2 случая)
- Удалены вводные: «в современном мире», «стоит отметить»
- Заменены англицизмы: «имплементация» → «внедрение»
- Исправлена типографика: кавычки «», тире –
- Сокращено количество метафор с 4 до 1
```

## Gotchas

Common model mistakes observed during humanization:

- **Over-removing hedging**: The model removes ALL uncertainty markers, including legitimate ones like `возможно` when the author intentionally expressed doubt. Keep factual uncertainty.
- **Aggressive anglicism purge**: The model replaces domain-standard terms (HR, KPI, API, CRM) thinking they are jargon. Only replace casual office slang, not industry terminology.
- **Metaphor over-counting**: The model counts only obvious metaphors (`стержень`, `фундамент`) but misses subtle ones. Count all figurative language, including idioms.
- **Paragraph rhythm flattening**: After transformation, all paragraphs become the same length. Deliberately vary paragraph length — short punch + longer explanation.
- **Citation damage**: The model rewrites around citation markers `[Лекция N, ЧЧ:ММ]` and breaks the reference. Keep citations attached to their claims.
- **"Что исправлено" padding**: The model generates generic change descriptions (`Улучшена читаемость`). Each bullet must describe a specific concrete change with count.

## Self-Check

Before delivering output, verify:
- [ ] Meaning fully preserved
- [ ] All forbidden phrases removed or rephrased
- [ ] No `не X, а Y` constructions remain
- [ ] Typography correct: en-dash `–`, guillemets `«»`
- [ ] Metaphors ≤ 2 in total
- [ ] Citations intact (if `preserve_citations=true`)
- [ ] No two adjacent paragraphs have identical rhythm/length
- [ ] `Что исправлено` section has 3-5 concrete points
- [ ] Text sounds like competent human writing, not forced de-AI-fication
