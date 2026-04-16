#!/bin/bash
# Update agent checkpoint state file.
# Writes to coordination/state/<agent>.md and optionally updates tasks.jsonl.

AGENT=""
TASK_ID=""
STATUS="in_progress"
ACTION=""
NOTE=""
NEXT_ACTION=""
RETRY_COUNT=0
SAME_ACTION=""
ACTION_RESULT=""
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --agent) AGENT="$2"; shift ;;
        --task-id) TASK_ID="$2"; shift ;;
        --status) STATUS="$2"; shift ;;
        --action) ACTION="$2"; shift ;;
        --note) NOTE="$2"; shift ;;
        --next-action) NEXT_ACTION="$2"; shift ;;
        --retry-count) RETRY_COUNT="$2"; shift ;;
        --same-action) SAME_ACTION="$2"; shift ;;
        --result) ACTION_RESULT="$2"; shift ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$AGENT" ] || [ -z "$TASK_ID" ]; then
    echo "Usage: $0 --agent <name> --task-id <id> --status <status> [--action <text>] [--note <text>]"
    exit 1
fi

STATE_DIR="$REPO_ROOT/coordination/state"
mkdir -p "$STATE_DIR"

STATE_FILE="$STATE_DIR/${AGENT}.md"
UPDATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

cat > "$STATE_FILE" << EOF
# Agent State

- agent: $AGENT
- task_id: $TASK_ID
- status: $STATUS
- last_updated_utc: $UPDATED_AT
- workspace: $REPO_ROOT
- last_action: $ACTION
- last_action_result: $ACTION_RESULT
- next_action: $NEXT_ACTION
- retry_count: $RETRY_COUNT
- consecutive_same_action: $SAME_ACTION
- notes:
  - $NOTE
EOF

echo "[checkpoint] $AGENT | $TASK_ID | $STATUS | $ACTION"

# Update tasks.jsonl
TASKS_FILE="$REPO_ROOT/coordination/tasks.jsonl"
if [ -n "$TASK_ID" ] && [ -f "$TASKS_FILE" ]; then
    TMP_FILE=$(mktemp)
    FOUND=0
    while IFS= read -r line || [ -n "$line" ]; do
        [ -z "$line" ] && continue
        # Use python for JSON manipulation if available
        if command -v python3 >/dev/null 2>&1; then
            updated=$(python3 -c "
import json, sys
try:
    obj = json.loads('''$line''')
    if obj.get('id') == '$TASK_ID':
        obj['status'] = '$STATUS'
        obj['updated_at'] = '$UPDATED_AT'
        print(json.dumps(obj, ensure_ascii=False))
        sys.exit(0)
    print('''$line''')
    sys.exit(1)
except:
    print('''$line''')
    sys.exit(1)
" 2>/dev/null)
            if [ $? -eq 0 ]; then
                FOUND=1
            fi
            echo "$updated" >> "$TMP_FILE"
        else
            echo "$line" >> "$TMP_FILE"
        fi
    done < "$TASKS_FILE"

    if [ "$FOUND" -eq 0 ]; then
        echo "{\"id\":\"$TASK_ID\",\"title\":\"$ACTION\",\"owner\":\"$AGENT\",\"status\":\"$STATUS\",\"checklist\":[],\"updated_at\":\"$UPDATED_AT\"}" >> "$TMP_FILE"
    fi

    mv "$TMP_FILE" "$TASKS_FILE"
    echo "[checkpoint] tasks.jsonl updated for $TASK_ID"
fi
