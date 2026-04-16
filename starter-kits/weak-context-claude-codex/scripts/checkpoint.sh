#!/usr/bin/env bash
set -euo pipefail

AGENT="${1:-codex}"
TASK_ID="${2:-}"
STATUS="${3:-in_progress}"
NOTE="${4:-Checkpoint updated.}"

if [[ "$AGENT" != "claude" && "$AGENT" != "codex" ]]; then
  echo "Agent must be 'claude' or 'codex'." >&2
  exit 1
fi

if [[ -z "$TASK_ID" ]]; then
  echo "Usage: bash ./scripts/checkpoint.sh [claude|codex] <task_id> [status] [note]" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="$ROOT_DIR/coordination/state"
STATE_PATH="$STATE_DIR/$AGENT.md"
mkdir -p "$STATE_DIR"

cat > "$STATE_PATH" <<EOF
# Agent State

- agent: $AGENT
- task_id: $TASK_ID
- status: $STATUS
- last_updated_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- workspace: $ROOT_DIR
- notes:
  - $NOTE
EOF

echo "Updated checkpoint: $STATE_PATH"
