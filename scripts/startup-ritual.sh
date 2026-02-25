#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
AGENT="opencode"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --repo-root <path>   Override repository root
  --agent <name>       Agent name (default: opencode)
  -h, --help           Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
      shift 2
      ;;
    --agent)
      AGENT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

TASKS_FILE="$REPO_ROOT/coordination/tasks.jsonl"
STATE_FILE="$REPO_ROOT/coordination/state/$AGENT.md"

if [[ ! -f "$TASKS_FILE" ]]; then
  echo "Tasks file not found: $TASKS_FILE" >&2
  exit 1
fi

if [[ ! -f "$STATE_FILE" ]]; then
  echo "State file not found: $STATE_FILE" >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "python3/python is required." >&2
  exit 1
fi

"$PYTHON_BIN" - "$TASKS_FILE" "$STATE_FILE" "$AGENT" <<'PY'
import json
import re
import sys

tasks_file, state_file, agent = sys.argv[1:4]

in_progress = []
with open(tasks_file, "r", encoding="utf-8") as f:
    for raw in f:
        line = raw.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        owner = str(obj.get("owner", ""))
        if obj.get("status") == "in_progress" and owner in (agent, "any"):
            in_progress.append(obj)

with open(state_file, "r", encoding="utf-8") as f:
    state_raw = f.read()

def state_value(key: str):
    m = re.search(rf"(?m)^- {re.escape(key)}:\s*`?([^`\r\n]+)`?\s*$", state_raw)
    return m.group(1) if m else None

print("Startup ritual")
print(f"Agent: {agent}")
print(f"Tasks file: {tasks_file}")
print(f"State file: {state_file}")
print()
print(f"In-progress tasks for {agent}: {len(in_progress)}")
for t in in_progress:
    print(f"- {t.get('id', '<no-id>')}: {t.get('title', '<no-title>')}")
print()
print("Current state snapshot:")
for key in ("task_id", "status", "last_updated_utc", "workspace"):
    val = state_value(key)
    if val is not None:
        print(f"- {key}: {val}")
print()
print("Next action: resume from saved checkpoint in coordination/state/<agent>.md and update state after each micro-step.")
PY
