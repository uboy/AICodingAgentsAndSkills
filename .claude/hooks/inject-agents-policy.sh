#!/usr/bin/env bash
set -euo pipefail

# inject-agents-policy.sh — Inject AGENTS-hot.md as additionalContext for Claude Code session
# SessionStart hook: fires on startup, resume, clear, compact
# Outputs JSON {"additionalContext": "..."} to inject policy rules into Claude's context.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
AGENTS_HOT=""

if [[ -f "$PROJECT_DIR/AGENTS-hot.md" ]]; then
  AGENTS_HOT="$PROJECT_DIR/AGENTS-hot.md"
elif [[ -f "$HOME/AGENTS-hot.md" ]]; then
  AGENTS_HOT="$HOME/AGENTS-hot.md"
fi

if [[ -z "$AGENTS_HOT" ]]; then
  exit 0
fi

# Use python for reliable JSON escaping; test actual execution (not just path presence)
PYTHON_BIN=""
if python3 -c "import sys" >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif python -c "import sys" >/dev/null 2>&1; then
  PYTHON_BIN="python"
fi

if [[ -n "$PYTHON_BIN" ]]; then
  "$PYTHON_BIN" -c "
import sys, json
content = open(sys.argv[1], encoding='utf-8').read()
print(json.dumps({'additionalContext': content}))
" "$AGENTS_HOT"
else
  # Fallback: plain stdout is also accepted by Claude Code as session context
  cat "$AGENTS_HOT"
fi
