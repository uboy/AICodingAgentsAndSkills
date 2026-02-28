# Eval: task-specifier

## Case 1 - Feature task with partial input

### Input

```
Нужно добавить страницу About с описанием продукта и кнопкой связи.
```

### Acceptance Checks

1. Output starts with `Clarifying Questions` section.
2. Output includes `Recommendations` section.
3. Output includes `Final Task Description` with `Task Type`.
4. Output includes `Expected Outcome` and `Proposed Change (High-Level)`.
5. Output includes `Out of Scope`.
6. Output does not contain `Subtasks` section.
7. Missing unknown fields are marked as `not specified`.

---

## Case 2 - Bug task with explicit repro details

### Input

```
Тип: bug.
Краш в профиле пользователя при открытии после logout/login.
Шаги: 1) Войти, 2) Выйти, 3) Войти заново, 4) Открыть профиль.
Ожидаемое: профиль открывается.
Фактическое: приложение падает.
```

### Acceptance Checks

1. Output keeps `Task Type` as `bug`.
2. `Expected Outcome` and `Scope` clearly describe the bug fix target.
3. Output includes `Clarifying Questions` before final description.
4. `Verification` includes explicit repro regression checks.
5. `Dependencies / Risks` exists with at least one concrete risk.
6. Output does not contain any decomposition into subtasks.
