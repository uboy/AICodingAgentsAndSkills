#!/usr/bin/env bash
# Generates a new task record in coordination/tasks.jsonl.
# Supports Manual, AI-assisted, and Direct CLI modes.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TASKS_FILE="$REPO_ROOT/coordination/tasks.jsonl"

JSON_LINE=""
MODE="1"
TASK_ID=""
TITLE=""
OWNER="any"
PRIORITY="medium"
STATUS="todo"

find_python() {
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then
      if "$candidate" -c "import json,sys" >/dev/null 2>&1; then
        printf "%s" "$candidate"
        return 0
      fi
    fi
  done
  return 1
}

PYTHON_BIN="$(find_python || true)"

build_task_json() {
  local task_id="$1"
  local title="$2"
  local owner="$3"
  local status="$4"
  local priority="$5"
  local updated_at="$6"

  if [[ -z "$PYTHON_BIN" ]]; then
    echo "python3/python is required to generate JSON safely." >&2
    exit 1
  fi

  "$PYTHON_BIN" - "$task_id" "$title" "$owner" "$status" "$priority" "$updated_at" <<'PY'
import json
import sys

task_id, title, owner, status, priority, updated_at = sys.argv[1:7]
task = {
    "id": task_id,
    "title": title,
    "owner": owner,
    "status": status,
    "priority": priority,
    "checklist": [{"id": "C-1", "text": "Implement change", "status": "todo"}],
    "depends_on": [],
    "inputs": [],
    "outputs": [],
    "updated_at": updated_at,
}
print(json.dumps(task, ensure_ascii=False, separators=(",", ":")))
PY
}

append_json_line() {
  local json_line="$1"
  printf '%s\n' "$json_line" >> "$TASKS_FILE"
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --json-line) JSON_LINE="$2"; shift ;;
    --mode) MODE="$2"; shift ;;
    --task-id) TASK_ID="$2"; shift ;;
    --title) TITLE="$2"; shift ;;
    --owner) OWNER="$2"; shift ;;
    --priority) PRIORITY="$2"; shift ;;
    --status) STATUS="$2"; shift ;;
    *) echo "Unknown parameter: $1" >&2; exit 1 ;;
  esac
  shift
done

# DIRECT JSON MODE
if [[ -n "$JSON_LINE" ]]; then
  if [[ -n "$PYTHON_BIN" ]]; then
    normalized_json="$("$PYTHON_BIN" - "$JSON_LINE" <<'PY'
import json
import sys

obj = json.loads(sys.argv[1])
print(json.dumps(obj, ensure_ascii=False, separators=(",", ":")))
PY
)"
    append_json_line "$normalized_json"
  elif [[ "$JSON_LINE" =~ \{.*\} ]]; then
    append_json_line "$JSON_LINE"
  else
    echo "Invalid JSON format." >&2
    exit 1
  fi
  echo "SUCCESS: Task added to tasks.jsonl via JSON."
  exit 0
fi

# NON-INTERACTIVE PARAMETER MODE
if [[ -n "$TITLE" ]]; then
  if [[ -z "$TASK_ID" ]]; then
    TASK_ID="T-$(date +%Y%m%d-%H%M%S)"
  fi
  UPDATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  TASK_JSON="$(build_task_json "$TASK_ID" "$TITLE" "$OWNER" "$STATUS" "$PRIORITY" "$UPDATED_AT")"
  append_json_line "$TASK_JSON"
  echo "SUCCESS: Task $TASK_ID added via parameters."
  exit 0
fi

# INTERACTIVE MODE
echo
echo "--- AI Agent Task Generator ---"
echo "1. AI Mode (takes a raw idea, researches files, proposes plan)"
echo "2. Manual Mode (standard prompts for all fields)"

read -r -p "Select Mode (default: $MODE): " selected_mode
selected_mode="${selected_mode:-$MODE}"

if [[ "$selected_mode" == "1" ]]; then
  echo
  echo "[AI MODE] Describe what you want to achieve in free text:"
  read -r -p "Idea: " raw_idea
  if [[ -z "$raw_idea" ]]; then
    echo "Idea is required." >&2
    exit 1
  fi

  echo
  echo "--- INSTRUCTION FOR AGENT ---"
  echo "Use 'task-specifier' skill for: $raw_idea"
  echo "Then run: scripts/generate-task.sh --json-line '<GENERATED_JSON>'"
  echo "-----------------------------"

  read -r -p "Paste TASK_JSON here: " json_input
  if [[ -z "$json_input" ]]; then
    echo "Task JSON is required." >&2
    exit 1
  fi
  if [[ -n "$PYTHON_BIN" ]]; then
    normalized_json="$("$PYTHON_BIN" - "$json_input" <<'PY'
import json
import sys

obj = json.loads(sys.argv[1])
print(json.dumps(obj, ensure_ascii=False, separators=(",", ":")))
PY
)"
    append_json_line "$normalized_json"
    echo "SUCCESS: Task added."
  elif [[ "$json_input" =~ \{.*\} ]]; then
    append_json_line "$json_input"
    echo "SUCCESS: Task added."
  else
    echo "Invalid JSON format." >&2
    exit 1
  fi
  exit 0
fi

# MANUAL MODE
read -r -p "Task Title: " manual_title
if [[ -z "$manual_title" ]]; then
  echo "Task title is required." >&2
  exit 1
fi
read -r -p "Owner (default: any): " manual_owner
manual_owner="${manual_owner:-any}"
read -r -p "Priority (default: medium): " manual_priority
manual_priority="${manual_priority:-medium}"

manual_task_id="T-$(date +%Y%m%d-%H%M%S)"
updated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
manual_json="$(build_task_json "$manual_task_id" "$manual_title" "$manual_owner" "$STATUS" "$manual_priority" "$updated_at")"
append_json_line "$manual_json"
echo "SUCCESS: Task $manual_task_id added."
