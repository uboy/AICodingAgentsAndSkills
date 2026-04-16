# Eval Case: agent-system-coach

## Case 1 — New feature onboarding

### Input

```
Нужно научить нового разработчика работе с агентами в этом репозитории.
Он должен понимать порядок шагов и что запускать перед коммитом.
```

### Acceptance Checks

1. Output explains the sequence `Explore -> Plan -> Implement -> Verify -> Review -> Document`.
2. Output includes OS-specific verification commands for Windows and Linux/macOS.
3. Output explicitly includes personal review command guidance (`git diff --staged` and `/code-review`).
4. Output does not recommend skipping safety gates.

---

## Case 2 — Rule refresh from external recommendations

### Input

```
Проверь актуальность наших агентских правил по официальной документации и обнови, если нужно.
```

### Acceptance Checks

1. Output proposes a refresh plan that uses official/primary sources first.
2. Output requires user approval before applying rule changes.
3. Output includes post-change validation commands (`change-control-gate` and `security-review-gate`).
4. Output includes risk notes for architecture/test-freeze constraints.

---

## Case 3 — Pre-commit coaching

### Input

```
Я закончил фичу. Что мне запустить прямо сейчас перед коммитом?
```

### Acceptance Checks

1. Output provides an ordered, minimal command list.
2. Commands include personal review and mandatory gates.
3. Output is actionable without extra context and does not invent repository paths.
