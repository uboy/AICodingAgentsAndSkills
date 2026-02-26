# Eval Case: task-progress

## Case 1 — Sufficient input (no clarification needed)

### Input

```
Задача: OHUI-1234 — Добавить поддержку pull-to-refresh в список новостей.
Что сделано: реализовал компонент NewsList с LazyForEach + Refresh, протестировал на
RK3568 под OH 4.1, фрейм-дроп не наблюдается.
Планирую: добавить юнит-тест для dataSource и запросить ревью.
Проблем нет, PR уже создан: #88.
```

### Acceptance Checks

1. No clarifying questions are asked — input covers done / next / risks / artifacts.
2. `Done` section contains at least one specific bullet referencing NewsList and LazyForEach.
3. `Risks` section explicitly names `list-perf` category (LazyForEach was used — good practice noted or confirmed).
4. `Artifacts` includes PR #88.
5. No invented facts (e.g., no fabricated test percentages or ETA).
6. Output is in English.

---

## Case 2 — Insufficient input (clarification round required)

### Input

```
Задача: исправить краш при открытии профиля пользователя
```

### Acceptance Checks

1. Skill asks at least 2 clarifying questions **in Russian** before generating the comment.
2. Questions cover at least two of: done / next / artifacts.
3. Questions do not contain invented facts about the task.
4. After simulated answers, the generated comment is in English.
5. `Risks` section is present — at minimum `lifecycle` or `state-observation` is flagged given a crash scenario.
6. Output omits sections that have no content (e.g., no `Blockers` section if none mentioned).

---

## Case 3 — Technical implementation task (two-section output)

### Input

```
Задача: OHUI-567 — Рефакторинг AudioManager: заменить callback-API на Promise-based.
Сделано: новый Promise API готов, старый callback-API помечен @deprecated, написаны
тесты для 12 сценариев. Все тесты зелёные.
Планируется: удалить callback-API в следующем релизе после периода deprecation.
Риск: внешние приложения, использующие callback-API, сломаются без миграции.
```

### Acceptance Checks

1. Output contains both a summary section and a `Technical Details` section separated by `---`.
2. `Risks` section includes `backward-compat` category with reference to callback-API callers.
3. `Done` section references Promise API, @deprecated marking, and test count (12 scenarios).
4. `Next` section mentions removal timeline / deprecation period.
5. No clarifying questions asked — input is sufficient.
6. Output is in English.
