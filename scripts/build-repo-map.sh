#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
OUTPUT_FILE=".scratchpad/repo-map.json"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --repo-root <path>     Override repository root
  --output-file <path>   Output file relative to repo root (default: .scratchpad/repo-map.json)
  -h, --help             Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
      shift 2
      ;;
    --output-file)
      OUTPUT_FILE="$2"
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

OUT_PATH="$REPO_ROOT/$OUTPUT_FILE"
mkdir -p "$(dirname "$OUT_PATH")"

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "python3/python is required." >&2
  exit 1
fi

"$PYTHON_BIN" - "$REPO_ROOT" "$OUT_PATH" <<'PY'
import fnmatch
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

repo_root, out_path = sys.argv[1:3]

patterns = [
    "BUILD.gn", "*.gn", "*.gni", "*.ninja", "build.ninja",
    "CMakeLists.txt", "*.cmake", "Makefile", "GNUmakefile", "*.mk",
    "package.json", "pnpm-workspace.yaml", "pyproject.toml", "setup.py",
    "requirements*.txt", "*.sh", "*.ps1",
]

def list_files():
    try:
        ok = subprocess.run(
            ["git", "-C", repo_root, "rev-parse", "--is-inside-work-tree"],
            check=False,
            capture_output=True,
            text=True,
        )
        if ok.returncode == 0 and ok.stdout.strip() == "true":
            out = subprocess.run(
                ["git", "-C", repo_root, "ls-files"],
                check=True,
                capture_output=True,
                text=True,
            )
            return [line.strip() for line in out.stdout.splitlines() if line.strip()]
    except Exception:
        pass

    all_files = []
    for root, _, files in os.walk(repo_root):
        for name in files:
            full = os.path.join(root, name)
            rel = os.path.relpath(full, repo_root).replace("\\", "/")
            all_files.append(rel)
    return all_files

files = list_files()

def is_build_file(path: str) -> bool:
    return any(fnmatch.fnmatch(path, p) or fnmatch.fnmatch(path.split("/")[-1], p) for p in patterns)

build_files = [f for f in files if is_build_file(f)]
entrypoints = [
    f for f in build_files
    if f.endswith("build.ninja")
    or f.endswith("BUILD.gn")
    or f.endswith("CMakeLists.txt")
    or f.endswith("Makefile")
    or f.endswith("package.json")
]

data = {
    "generated_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "repo_root": repo_root,
    "total_files": len(files),
    "build_files_count": len(build_files),
    "build_entrypoints": entrypoints,
    "build_files": build_files,
}

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=True, indent=2)

print(f"Repo map written: {out_path}")
print(f"Build files: {len(build_files)}")
print(f"Entrypoints: {len(entrypoints)}")
PY
