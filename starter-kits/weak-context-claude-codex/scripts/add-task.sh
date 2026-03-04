#!/usr/bin/env bash
set -euo pipefail

TITLE="${1:-}"
OWNER="${2:-codex}"
TASK_ID="${3:-}"
PRIORITY="${4:-medium}"

if [[ -z "$TITLE" ]]; then
  echo "Usage: bash ./scripts/add-task.sh \"Task title\" [claude|codex] [task_id] [low|medium|high]" >&2
  exit 1
fi

if [[ "$OWNER" != "claude" && "$OWNER" != "codex" ]]; then
  echo "Owner must be 'claude' or 'codex'." >&2
  exit 1
fi

if [[ -z "$TASK_ID" ]]; then
  TASK_ID="T-$(date -u +%Y%m%d-%H%M%S)"
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASKS_PATH="$ROOT_DIR/coordination/tasks.jsonl"
mkdir -p "$(dirname "$TASKS_PATH")"
touch "$TASKS_PATH"

TITLE_ESCAPED="${TITLE//\\/\\\\}"
TITLE_ESCAPED="${TITLE_ESCAPED//\"/\\\"}"
UPDATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

printf '%s\n' "{\"id\":\"$TASK_ID\",\"title\":\"$TITLE_ESCAPED\",\"owner\":\"$OWNER\",\"status\":\"todo\",\"priority\":\"$PRIORITY\",\"checklist\":[{\"id\":\"C-1\",\"text\":\"Execute one micro-step and verify acceptance\",\"status\":\"todo\"},{\"id\":\"C-2\",\"text\":\"Run syntax/lint/tests for this micro-step\",\"status\":\"todo\"},{\"id\":\"C-3\",\"text\":\"Update state and handoff\",\"status\":\"todo\"}],\"depends_on\":[],\"inputs\":[],\"outputs\":[],\"profile\":\"weak_model\",\"updated_at\":\"$UPDATED_AT\"}" >> "$TASKS_PATH"

echo "Added task $TASK_ID to $TASKS_PATH"
