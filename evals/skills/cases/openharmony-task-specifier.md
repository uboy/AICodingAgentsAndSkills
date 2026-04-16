# Eval: openharmony-task-specifier

## Case 1 - ArkUI feature task with weak input

### Input

```
Нужно улучшить экран списка новостей в ArkUI.
```

### Acceptance Checks

1. Output starts with `Clarifying Questions`.
2. Output includes `Recommendations`.
3. Output includes `OpenHarmony Technical Context` section.
4. Output includes both `Expected Outcome` and `Proposed Change (High-Level)`.
5. Output includes named risk categories (for example `rendering-perf`, `list-perf`).
6. Output does not contain `Subtasks` section.
7. Unknown technical values are marked as `not specified`.

---

## Case 2 - OpenHarmony bug with lifecycle impact

### Input

```
Type: bug.
When app goes to background and returns, camera preview does not recover.
Affects UIAbility lifecycle.
Expected: camera preview resumes after foreground.
Actual: black preview area remains until app restart.
```

### Acceptance Checks

1. `Task Type` is `bug`.
2. `Risks and Dependencies` includes `lifecycle` category.
3. `Verification` includes lifecycle transition scenario (background -> foreground).
4. `Acceptance Criteria` are testable and explicit.
5. Output contains no fabricated device/API-level data.
6. Output contains no decomposition into subtasks.
