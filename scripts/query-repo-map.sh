#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
MAP_FILE=".scratchpad/repo-map.json"
QUERY=""
LIMIT=30

usage() {
  cat <<EOF
Usage: $(basename "$0") --query <text> [options]

Options:
  --repo-root <path>   Override repository root
  --map-file <path>    Map file relative to repo root (default: .scratchpad/repo-map.json)
  --query <text>       Query text (required)
  --limit <n>          Max matches (default: 30)
  -h, --help           Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
      shift 2
      ;;
    --map-file)
      MAP_FILE="$2"
      shift 2
      ;;
    --query)
      QUERY="$2"
      shift 2
      ;;
    --limit)
      LIMIT="$2"
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

if [[ -z "$QUERY" ]]; then
  echo "--query is required" >&2
  usage
  exit 1
fi

MAP_PATH="$REPO_ROOT/$MAP_FILE"
if [[ ! -f "$MAP_PATH" ]]; then
  echo "Repo map not found: $MAP_PATH (run build-repo-map first)" >&2
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

"$PYTHON_BIN" - "$MAP_PATH" "$QUERY" "$LIMIT" <<'PY'
import json
import sys

map_path, query, limit_raw = sys.argv[1:4]
limit = int(limit_raw)

with open(map_path, "r", encoding="utf-8") as f:
    data = json.load(f)

files = data.get("build_files", [])
q = query.lower()
hits = [p for p in files if q in p.lower()][:limit]

print(f"Query: {query}")
print(f"Matches: {len(hits)}")
for h in hits:
    print(f"- {h}")

if not hits:
    print("No matches in build file map. Try a broader query.")
PY
