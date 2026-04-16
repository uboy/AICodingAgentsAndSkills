# Eval Case: text-humanize

## Case 1 - Remove template AI phrasing

### Input

```text
В современном мире важно понимать, что качественный сервис играет ключевую роль в формировании доверия. Это не просто удобство, а важнейший фактор долгосрочного взаимодействия с клиентом.
```

### Acceptance Checks

1. Core meaning is preserved.
2. Phrases like `в современном мире` and `важно понимать` are removed or rewritten.
3. Construction `это не просто X, а ...` does not remain in the result.
4. Output sounds like natural Russian prose, not polished template copy.
5. Response includes a short `Что исправлено` block with 3-5 points.

---

## Case 2 - Preserve detail, fix mixed style

### Input

```text
Когда команда три недели подряд не может закрыть один и тот же баг, это уже выглядит как системная история. Нужен нормальный ресерч, потом апдейт процесса и понятный фидбек для всех участников.
```

### Acceptance Checks

1. Cause-and-effect logic stays intact.
2. Unnecessary anglicisms such as `ресерч`, `апдейт`, `фидбек` are replaced with natural Russian where appropriate.
3. Tone stays direct and slightly sharp, without smoothing the author's position.
4. Typography uses `–` for dash and `«ёлочки»` if quotes appear.
5. Response format is `переписанный текст` followed by `Что исправлено`.
