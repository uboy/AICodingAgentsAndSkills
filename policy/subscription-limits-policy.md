# Subscription Limits Policy

## Purpose

Define how agents monitor and respond to subscription token usage limits during a session.
This policy is referenced by AGENTS.md Rule 36.

## Configuration

Configuration is stored in `configs/subscription-limits.json`:

| Field | Default | Description |
|-------|---------|-------------|
| `subscription_limit_tokens` | 200000 | Approximate token limit per subscription period |
| `warning_threshold_pct` | 0.80 | Emit inline warning when usage reaches this fraction |
| `critical_threshold_pct` | 0.90 | Emit warning + suggest `auto_resume` |
| `auto_resume` | false | If true, auto-sleep and resume from checkpoint when limit hit |
| `token_spend_gate.enabled` | false | If true, pause and ask user confirmation when cumulative spend exceeds threshold |
| `token_spend_gate.threshold_tokens` | 1000000 | Token spend gate threshold |

## Session Tracking

- State file: `coordination/state/session-usage.json` (local runtime, not committed)
- Updated after each major operation (tool call, sub-agent delegation, file write)
- Tracks: `cumulative_tokens`, `operations_count`, `last_updated`

## Behavior at Thresholds

### >= 80% (Warning)

- Agent emits inline warning: `[subscription-warning] ~X% of subscription limit used`
- Continue operation normally

### >= 90% (Critical)

- Agent emits warning with suggestions:
  - Enable `auto_resume` in config
  - Save checkpoint via `.scratchpad/`
  - Finish critical path first, defer non-essential work

### 100% or HTTP 429

- **`auto_resume: false`** (default):
  1. Save checkpoint to `coordination/state/<agent>.md` + `.scratchpad/`
  2. Notify user
  3. Stop — agent will not continue
  4. Recovery: `scripts/resume-on-limit.ps1` / `.sh`

- **`auto_resume: true`**:
  1. Save checkpoint
  2. Calculate reset time from 429 headers or config
  3. Sleep until reset
  4. Auto-resume from last checkpoint

## Token Spend Gate

When `token_spend_gate.enabled: true`:
- If cumulative session tokens exceed `threshold_tokens`:
  - Pause BEFORE next major operation
  - Ask user: "Cumulative token spend has exceeded N. Continue?"
  - If user declines: save checkpoint and stop

## Recovery Scripts

- Windows: `scripts/resume-on-limit.ps1`
- Linux/macOS: `scripts/resume-on-limit.sh`

Both scripts:
1. Read checkpoint from `coordination/state/<agent>.md`
2. Restore context from `.scratchpad/`
3. Resume agent from last saved operation

## Cross-System Alignment

This policy applies identically to:
- Claude Code, Codex CLI, Cursor, Gemini CLI, OpenCode, Qwen Code

Adapter-specific implementations may differ in HOW they track tokens,
but the threshold behavior and checkpoint protocol must remain aligned.
