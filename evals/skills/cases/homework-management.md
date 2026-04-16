# Eval Case: homework-management

## Case 1 - Source-grounded essay

### Input

```text
mode: essay
subject: HR-менеджмент
topic: Почему модель компетенций влияет на качество найма
sources:
- Лекция 2, слайды 5-12
- Лекция 3, таймкоды 12:10-21:40
citation_mode: inline
word_limit: 900
language: Russian
```

### Acceptance Checks

1. Output follows the `essay` structure from the skill contract.
2. Every substantive claim about HR theory or hiring practice is backed by a source citation.
3. No external facts, authors, or studies are invented beyond the provided sources.
4. Conclusion ties back to the stated topic and earlier argument, not to generic filler.
5. If source coverage is insufficient for any required section, the gap is flagged explicitly.

---

## Case 2 - Business case with incomplete evidence

### Input

```text
mode: business_case
subject: Управление проектами
topic: Разобрать причины срыва сроков в кейсе внедрения CRM
sources:
- Кейс компании, 2 страницы
- Лекция 5, таймкоды 08:00-14:30
citation_mode: footnote
language: Russian
```

### Acceptance Checks

1. Output follows the `business_case` structure from the skill contract.
2. Analysis of causes is linked to lecture theory and to details from the provided case.
3. Recommended action is practical and grounded in the provided materials.
4. Missing evidence is called out directly instead of being invented.
5. Source list matches the citations used in the text.
