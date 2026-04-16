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
STATE_DIR="$REPO_ROOT/coordination/state"
STATE_FILE="$STATE_DIR/$AGENT.md"
STATE_TEMPLATE="$REPO_ROOT/coordination/templates/state.md"
SESSION_USAGE_FILE="$STATE_DIR/session-usage.json"

mkdir -p "$STATE_DIR"

if [[ ! -f "$STATE_FILE" ]]; then
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [[ -f "$STATE_TEMPLATE" ]]; then
    sed \
      -e "s#<name>#$AGENT#g" \
      -e "s#1970-01-01T00:00:00Z#$ts#g" \
      "$STATE_TEMPLATE" > "$STATE_FILE"
  else
    cat > "$STATE_FILE" <<EOF
# Agent State

- agent: $AGENT
- branch: agent/$AGENT
- task_id: none
- status: idle
- last_updated_utc: $ts
- workspace: .worktrees/$AGENT
- notes:
  - bootstrapped by scripts/startup-ritual.sh
EOF
  fi
fi

if [[ ! -f "$SESSION_USAGE_FILE" ]]; then
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  session_id="$(printf '%s-%s' "$(printf '%s' "$ts" | tr -d ':-')" "$AGENT")"
  cat > "$SESSION_USAGE_FILE" <<EOF
{
  "_comment": "Per-session usage tracker. Updated by agents. See policy/subscription-limits-policy.md",
  "session_id": "$session_id",
  "agent": "$AGENT",
  "session_start_utc": "$ts",
  "last_checkpoint_utc": "$ts",
  "estimated_tokens_used": 0,
  "estimated_usage_percent": 0,
  "gate_tokens_since_last_confirm": 0,
  "auto_resume_attempts": 0,
  "status": "idle",
  "resume_after_utc": null,
  "last_completed_step": "none",
  "next_step": "startup"
}
EOF
fi

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "python3/python is required." >&2
  exit 1
fi

"$PYTHON_BIN" - "$TASKS_FILE" "$STATE_FILE" "$AGENT" "$SESSION_USAGE_FILE" <<'PY'
import json
import os
import re
import sys

tasks_file, state_file, agent, session_usage_file = sys.argv[1:5]

in_progress = []
try:
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
except FileNotFoundError:
    pass

with open(state_file, "r", encoding="utf-8") as f:
    state_raw = f.read()

def state_value(key: str):
    m = re.search(rf"(?m)^- {re.escape(key)}:\s*`?([^`\r\n]+)`?\s*$", state_raw)
    return m.group(1) if m else None

print("Startup ritual")
print(f"Agent: {agent}")
if os.path.exists(tasks_file):
    print(f"Tasks file: {tasks_file}")
else:
    print(f"Tasks file: {tasks_file} (not initialized; local tracker optional)")
print(f"State file: {state_file}")
print(f"Session usage file: {sys.argv[4]}")
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
print("Next action: resume from saved checkpoint in coordination/state/<agent>.md and update state after each micro-step. If no local tasks.jsonl exists yet, continue with state + scratchpad only.")
PY
