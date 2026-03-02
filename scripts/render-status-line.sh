#!/usr/bin/env bash
set -euo pipefail

SYSTEM="${1:-unknown}"
REPO_ROOT="${2:-}"
INPUT_JSON="$(cat 2>/dev/null || true)"

PYTHON_BIN=""
if python3 -c "import sys" >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif python -c "import sys" >/dev/null 2>&1; then
  PYTHON_BIN="python"
fi

if [[ -z "$PYTHON_BIN" ]]; then
  echo "$SYSTEM | ag:$SYSTEM | sk:- | step:- | chk:0/0 | task:- | ctx:-"
  exit 0
fi

RSL_INPUT_JSON="$INPUT_JSON" "$PYTHON_BIN" - "$SYSTEM" "$REPO_ROOT" <<'PY'
import json
import os
import re
import sys
from pathlib import Path

system = sys.argv[1] if len(sys.argv) > 1 else "unknown"
repo_hint = sys.argv[2] if len(sys.argv) > 2 else ""
input_json = os.environ.get("RSL_INPUT_JSON", "")

def find_repo_root(hint: str) -> str:
    candidates = []
    if hint:
        candidates.append(Path(hint))
    env_root = os.environ.get("AI_AGENT_REPO_ROOT", "")
    if env_root:
        candidates.append(Path(env_root))
    cur = Path.cwd()
    candidates.extend([cur] + list(cur.parents))
    for c in candidates:
        if (c / "coordination" / "tasks.jsonl").is_file():
            return str(c)
    return ""

def read_state_value(path: Path, key: str) -> str:
    if not path.is_file():
        return ""
    pattern = re.compile(r"^\s*-\s*%s:\s*`?([^`]+)`?\s*$" % re.escape(key))
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = pattern.match(line)
        if m:
            return m.group(1).strip()
    return ""

def read_tasks(path: Path):
    out = []
    if not path.is_file():
        return out
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except Exception:
            pass
    return out

def pick_task(tasks, agent: str):
    for t in reversed(tasks):
        if t.get("status") == "in_progress" and t.get("owner") in (agent, "any"):
            return t
    for t in reversed(tasks):
        if t.get("status") == "in_progress":
            return t
    return None

def shorten(text: str, max_len: int) -> str:
    text = re.sub(r"\s+", " ", (text or "")).strip()
    if not text:
        return "-"
    if len(text) <= max_len:
        return text
    return text[: max_len - 1] + "…"

root = find_repo_root(repo_hint)
agent = system
skill = "-"
task_id = "-"
step = "-"
done = 0
total = 0

if root:
    state_file = Path(root) / "coordination" / "state" / f"{system}.md"
    parsed_agent = read_state_value(state_file, "agent")
    if parsed_agent:
        agent = parsed_agent
    parsed_skill = read_state_value(state_file, "skill")
    if parsed_skill:
        skill = parsed_skill

    tasks = read_tasks(Path(root) / "coordination" / "tasks.jsonl")
    active = pick_task(tasks, agent)
    if active:
        task_id = str(active.get("id") or "-")
        checklist = active.get("checklist") or []
        total = len(checklist)
        done = sum(1 for c in checklist if str(c.get("status")) == "done")
        current = next((c for c in checklist if c.get("status") == "in_progress"), None)
        if current is None:
            current = next((c for c in checklist if c.get("status") == "todo"), None)
        if current is None and checklist:
            current = checklist[-1]
        if current:
            step = str(current.get("text") or "-")

model = system
ctx = "-"
if input_json.strip():
    try:
        obj = json.loads(input_json)
        model = str(((obj.get("model") or {}).get("display_name")) or model)
        used = ((obj.get("context_window") or {}).get("used_percentage"))
        if used is not None and str(used).strip() != "":
            ctx = f"{float(used):.0f}%"
    except Exception:
        pass

line = (
    f"{shorten(model, 20)} | ag:{shorten(agent, 12)} | sk:{shorten(skill, 14)} | "
    f"step:{shorten(step, 28)} | chk:{done}/{total} | task:{shorten(task_id, 18)} | ctx:{ctx}"
)
print(line)
PY
