#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
OUT_PATH="$REPO_ROOT/deploy/skill-deployment-manifest.tsv"
CHECK=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --repo-root <path>    Override repository root
  --out <path>          Output TSV path (default: deploy/skill-deployment-manifest.tsv)
  --check               Validate the existing TSV instead of rewriting it
  -h, --help            Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
      OUT_PATH="$REPO_ROOT/deploy/skill-deployment-manifest.tsv"
      shift 2
      ;;
    --out)
      OUT_PATH="$2"
      shift 2
      ;;
    --check)
      CHECK=1
      shift
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

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "python3 or python is required to generate the skill deployment manifest." >&2
  exit 1
fi

CMD=(
  "$PYTHON_BIN"
  "$SCRIPT_DIR/generate_skill_deployment_manifest.py"
  --repo-root "$REPO_ROOT"
  --out "$OUT_PATH"
)
if [[ $CHECK -eq 1 ]]; then
  CMD+=(--check)
fi

"${CMD[@]}"
