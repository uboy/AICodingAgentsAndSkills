#!/usr/bin/env bash
set -euo pipefail

AGENT="${1:-codex}"
if [[ "$AGENT" != "claude" && "$AGENT" != "codex" ]]; then
  echo "Agent must be 'claude' or 'codex'." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COORD_DIR="$ROOT_DIR/coordination"
STATE_DIR="$COORD_DIR/state"
TASKS_PATH="$COORD_DIR/tasks.jsonl"
STATE_PATH="$STATE_DIR/$AGENT.md"

mkdir -p "$STATE_DIR" "$COORD_DIR/handoffs" "$COORD_DIR/reviews" "$ROOT_DIR/.scratchpad"
touch "$TASKS_PATH"

if [[ ! -f "$STATE_PATH" ]]; then
  cat > "$STATE_PATH" <<EOF
# Agent State

- agent: $AGENT
- task_id: none
- status: idle
- last_updated_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- notes:
  - State file created by startup ritual.
EOF
fi

echo "[Startup Ritual] Agent: $AGENT"
echo "In-progress tasks:"
grep "\"owner\":\"$AGENT\"" "$TASKS_PATH" | grep "\"status\":\"in_progress\"" || echo "No in-progress tasks for this agent."
echo
echo "State file: $STATE_PATH"
cat "$STATE_PATH"
