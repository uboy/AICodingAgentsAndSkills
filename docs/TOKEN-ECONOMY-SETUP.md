# Token Economy System — Full Setup

> Все исправления от 2026-04-12. Проблема: токены расходовались быстро, compaction не срабатывал вовремя.

## Корень проблемы

1. **Hooks НЕ были настроены** для Codex и Gemini — только Claude имел SessionStart hook
2. **Пороги compaction слишком высокие** — Claude 95%, Qwen Code 70%, Gemini 50%
3. **Session state НЕ сохранялся** между перезапусками — каждый раз полная загрузка контекста
4. **Gemini использовал неправильный ключ** `statusLine` вместо `ui.footer.items`

## Что исправлено

### 1. Claude Code

| Компонент | Файл | Что делает |
|-----------|------|-----------|
| Status Line | `.claude/settings.json` → `statusLine` | PowerShell: `%USERPROFILE%\.claude\statusline.ps1` |
| SessionStart Hook | `.claude/hooks/inject-agents-policy.ps1` | Загружает AGENTS-hot.md в контекст |
| PreCompact Hook | `.claude/hooks/pre-compact.ps1` | Логирует compact, сохраняет контекст |
| Compaction | Auto ~95%, manual `/compact` | Ручной вызов при 50-60% |

### 2. Codex

| Компонент | Файл | Что делает |
|-----------|------|-----------|
| Status Line | `.codex/config.toml` → `[tui] status_line` | Built-in segments: model, context, dir, branch |
| SessionStart Hook | `.codex/hooks/session-start.ps1` | Загружает policy + восстанавливает state |
| Stop Hook | `.codex/hooks/save-session-state.ps1` | Сохраняет state для следующего запуска |
| Compaction | `model_auto_compact_token_limit = 64000` | Auto ~90%, manual `/compact` |
| Hooks Enabled | `[features] codex_hooks = true` | **Критично:** без этого hooks.json игнорируется |

### 3. Gemini CLI

| Компонент | Файл | Что делает |
|-----------|------|-----------|
| Status Footer | `.gemini/settings.json` → `ui.footer.items` | `["model", "context", "cwd"]` — НЕ `statusLine` |
| SessionStart Hook | `.gemini/hooks/session-start.ps1` | Загружает policy + восстанавлиет state |
| PreCompress Hook | `.gemini/hooks/pre-compress.ps1` | Сохраняет контекст перед сжатием |
| SessionEnd Hook | `.gemini/hooks/save-session-state.ps1` | Сохраняет state при выходе |
| Compaction | `compressionThreshold: 0.2` | **20%** — самый агрессивный порог |
| Hooks Config | `.gemini/hooks.json` | `hooksConfig.enabled: true` |

### 4. Cursor

| Компонент | Настройка | Что делает |
|-----------|-----------|-----------|
| Status Line | `/statusline` в IDE | User-configured, не через файлы |
| Compaction | Auto 100%, manual `/summarize` | IDE-internal |
| Policy | `.cursor/rules/*.mdc` | Rule 23: Context efficiency |

### 5. OpenCode

| Компонент | Файл | Что делает |
|-----------|------|-----------|
| Compaction | `opencode.json` → `compaction` | `auto: true, prune: true, reserved: 4000` |
| Status Line | ❌ Не поддерживается schema | |

### 6. Qwen Code

| Компонент | Файл | Что делает |
|-----------|------|-----------|
| Status Line | `~/.qwen/settings.json` → `ui.statusLine` | PowerShell: `%USERPROFILE%\.qwen\statusline-command.ps1` |
| Compaction | `chatCompression.contextPercentageThreshold: 0.5` | **50%** — было 70% |
| Manual | `/compress` | Ручное сжатие |

## Пороги compaction (после исправлений)

| Система | Было | Стало | Экономия |
|---------|------|-------|----------|
| Claude | ~95% | ~95% (auto) | PreCompact hook сохраняет state |
| Codex | не настроен | 64k tokens | ~90% ceiling |
| Gemini | 50% | **20%** | Самый агрессивный |
| Cursor | 100% | 100% (IDE) | `/summarize` вручную |
| OpenCode | auto | auto | `prune: true` |
| Qwen Code | 70% | **50%** | Раннее сжатие |

## Hooks Architecture

```
Session Start → Load AGENTS-hot.md (3000 chars max) + restore state
     ↓
Working... → Micro-steps, bounded context (policy/context-budget-policy.md)
     ↓
PreCompact/PreCompress → Log + preserve task state
     ↓
Compaction → Server-side or local summarization
     ↓
Session End → Save state to coordination/state/<system>.md
```

## Ручная экономия токенов (когда ждать auto — плохо)

1. **Используйте `/compact` или `/compress` при 50-60%** — не ждите auto
2. **Разбивайте большие задачи** — `policy/context-budget-policy.md` Rule 4: micro-steps
3. **Пишите state в файлы** — `coordination/state/<agent>.md`, не держите в диалоге
4. **Используйте bundles** — `bundles/*.md` для pre-assembled context
5. **Избегайте чтения больших файлов** — `skills/large-codebase-context/SKILL.md`

## Файлы проекта

```
.claude/
  settings.json          → statusLine + hooks (SessionStart, PreCompact)
  statusline.ps1         → PowerShell статусная строка
  hooks/
    inject-agents-policy.ps1  → SessionStart hook
    pre-compact.ps1           → PreCompact hook

.codex/
  config.toml            → [tui] status_line + compaction + codex_hooks
  hooks.json             → SessionStart + Stop hooks
  hooks/
    session-start.ps1        → Load policy + state
    save-session-state.ps1   → Save state on exit

.gemini/
  settings.json          → ui.footer.items + compressionThreshold: 0.2
  hooks.json             → SessionStart + PreCompress + SessionEnd
  hooks/
    session-start.ps1        → Load policy + state
    pre-compress.ps1         → PreCompress logger
    save-session-state.ps1   → Save state on exit
```
