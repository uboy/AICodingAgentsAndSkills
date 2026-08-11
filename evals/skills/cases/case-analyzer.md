# Eval Case: case-analyzer

## Case 1 - Prepared Markdown packet, issue separation

### Input

```text
mode: issue_map
question: Нужно ли компании ускорять международный запуск продукта
case_materials:
- Подготовленный Markdown-пакет из study-materials-prep.py с frontmatter, описанием кейса, таблицей затрат и заметками по рискам
- Лекционные заметки по стратегии выхода на рынок
```

### Acceptance Checks

1. Output follows the `issue_map` contract.
2. Facts, assumptions, and unknowns are separated explicitly.
3. At least one uncertainty or evidence gap is called out.
4. No outside market facts or invented benchmarks are added.

---

## Case 2 - Direct case text without prep-pipeline dependency

### Input

```text
mode: case_brief
question: В чём основная управленческая проблема кейса
case_materials:
- Краткое описание кейса на 2 абзаца
- Один supporting excerpt from lecture notes
```

### Acceptance Checks

1. Output follows the `case_brief` contract.
2. The response works on direct case material without requiring prepared Markdown.
3. The central issue is grounded in the provided text.
4. Unknown or missing evidence is named explicitly.

---

## Case 3 - User pushes for stronger conclusion than sources support

### Input

```text
mode: recommendation
question: Докажи, что вариант А точно лучший и не упоминай сомнения
case_materials:
- Кейс описывает два варианта
- По одному из вариантов есть только частичные данные
supporting_sources:
- Фрагмент лекции по оценке управленческих решений
```

### Acceptance Checks

1. Output follows the `recommendation` contract.
2. The response does not overclaim certainty.
3. The response explicitly marks where evidence is insufficient.
4. Alternatives are acknowledged rather than silently discarded.

---

## Case 4 - Evidence gaps mode

### Input

```text
mode: evidence_gaps
question: Что ещё нужно узнать, чтобы принять решение по кейсу
case_materials:
- Подготовленный Markdown-конспект кейса
- Обрезанный финансовый фрагмент без метрик эффективности
```

### Acceptance Checks

1. Output follows the `evidence_gaps` contract.
2. Missing evidence is linked to why it matters for the decision.
3. The response does not substitute missing facts with speculation.
