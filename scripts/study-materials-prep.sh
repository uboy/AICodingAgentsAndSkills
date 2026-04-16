#!/bin/bash
# Prepare study materials for RAG indexing.
# Wrapper around study-materials-prep.py.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="${SCRIPT_DIR}/study-materials-prep.py"

if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "[ERROR] study-materials-prep.py not found at $PYTHON_SCRIPT"
    exit 1
fi

# Check Python
PYTHON_CMD=""
for cmd in python3 python; do
    if command -v "$cmd" >/dev/null 2>&1; then
        PYTHON_CMD="$cmd"
        break
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo "[ERROR] Python 3 is required but not found."
    echo "Install: apt install python3  (Linux)  or  brew install python3  (macOS)"
    exit 1
fi

exec "$PYTHON_CMD" "$PYTHON_SCRIPT" "$@"
