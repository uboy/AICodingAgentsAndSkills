#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
INDEX="$REPO_ROOT/.agent-memory/index.jsonl"

if [[ ! -f "$INDEX" ]]; then
  echo "MISSING_INDEX:$INDEX"
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "ERROR: python3/python is required."
  exit 1
fi

"$PYTHON_BIN" - "$INDEX" <<'PY'
import datetime
import json
import sys

idx = sys.argv[1]
today = datetime.date.today()
stale = []

with open(idx, "r", encoding="utf-8") as f:
    for raw in f:
        line = raw.strip()
        if not line:
            continue
        row = json.loads(line)
        last = row.get("last_verified_on")
        gap = row.get("verify_after_days")
        if not last or gap is None:
            continue
        due = datetime.date.fromisoformat(last) + datetime.timedelta(days=int(gap))
        if today > due:
            stale.append((row.get("id", ""), row.get("technology", ""), due.isoformat()))

if not stale:
    print("OK: no stale entries")
    raise SystemExit(0)

print("STALE_ENTRIES:")
for item in sorted(stale, key=lambda x: (x[2], x[0])):
    print("\t".join(item))
raise SystemExit(2)
PY
