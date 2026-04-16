#!/usr/bin/env bash
# run-integrity-fast.sh — Build + quick validation (Linux/macOS)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== run-integrity-fast ==="
echo "Root: $ROOT"

# Step 1: Build
echo ""
echo "--- Step 1: sync-adapters ---"
bash "$SCRIPT_DIR/sync-adapters.sh"

# Step 2: Validate parity
echo ""
echo "--- Step 2: validate-parity ---"
bash "$SCRIPT_DIR/validate-parity.sh"

# Step 3: Syntax check all .sh scripts
echo ""
echo "--- Step 3: bash -n syntax check ---"
FAIL=0
for f in "$SCRIPT_DIR"/*.sh; do
    if bash -n "$f" 2>/dev/null; then
        echo "  OK: $(basename "$f")"
    else
        echo "  FAIL: $(basename "$f")"
        FAIL=1
    fi
done

# Step 4: Validate skills
echo ""
echo "--- Step 4: validate-skills ---"
bash "$SCRIPT_DIR/validate-skills.sh"

# Step 5: Validate coordination
echo ""
echo "--- Step 5: validate-coordination ---"
bash "$SCRIPT_DIR/validate-coordination.sh"

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== run-integrity-fast: PASS ==="
else
    echo "=== run-integrity-fast: FAIL ==="
    exit 1
fi
