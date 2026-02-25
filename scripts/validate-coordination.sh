#!/usr/bin/env bash
set -euo pipefail

# SYNOPSIS
#     Validates coordination artifacts (handoffs, plans) for required sections and format.
#     Follows AGENTS.md Rule 17 (Delivery Contract) and Rule 21 (Orchestration).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
HANDOFFS_DIR="$REPO_ROOT/coordination/handoffs/"

if [[ ! -d "$HANDOFFS_DIR" ]]; then
  echo "Coordination handoffs directory not found: $HANDOFFS_DIR"
  exit 0
fi

if python3 -c "import sys" 2>/dev/null; then
  PYTHON_BIN="python3"
elif python -c "import sys" 2>/dev/null; then
  PYTHON_BIN="python"
else
  echo "Error: python3/python is required for coordination validation."
  exit 1
fi

"$PYTHON_BIN" - "$REPO_ROOT" <<'PY'
import os
import re
import sys

repo_root = sys.argv[1]
handoffs_dir = os.path.join(repo_root, "coordination/handoffs/")
fail_count = 0

if not os.path.exists(handoffs_dir):
    sys.exit(0)

required_sections = [
    r"^## Summary",
    r"^## Files Touched",
    r"^## Verification",
]
# Accept either ## Delivery Contract or ## Commit Message
commit_section_pattern = r"^## (Delivery Contract|Commit Message)"

for filename in os.listdir(handoffs_dir):
    if not filename.endswith(".md") or filename == ".gitkeep":
        continue
    
    filepath = os.path.join(handoffs_dir, filename)
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    
    missing = []
    for section in required_sections:
        if not re.search(section, content, re.MULTILINE):
            missing.append(section.replace("^", ""))
            
    if missing:
        print("FAIL: {} is missing required sections: {}".format(filename, ', '.join(missing)))
        fail_count += 1
        continue

    # Verify ## Verification is not empty/placeholder
    verification_match = re.search(r"## Verification\s*\n(.*?)(?:\n##|$)", content, re.DOTALL)
    if verification_match:
        body = verification_match.group(1).strip()
        if not body or "<command" in body.lower() or body.lower() == "todo":
            print("FAIL: {} has empty or placeholder ## Verification section.".format(filename))
            fail_count += 1
    else:
        print("FAIL: {} could not parse ## Verification section body.".format(filename))
        fail_count += 1

    # Verify ## Delivery Contract or ## Commit Message is not empty/placeholder
    if not re.search(commit_section_pattern, content, re.MULTILINE):
        print("FAIL: {} is missing ## Delivery Contract or ## Commit Message section.".format(filename))
        fail_count += 1
    else:
        commit_match = re.search(
            r"## (?:Delivery Contract|Commit Message)\s*\n(.*?)(?:\n##|$)", content, re.DOTALL
        )
        if commit_match:
            body = commit_match.group(1).strip()
            if not body or body.lower() == "todo":
                print("FAIL: {} has empty or placeholder delivery/commit section.".format(filename))
                fail_count += 1

if fail_count > 0:
    print("\nCoordination validation FAILED with {} error(s).".format(fail_count))
    sys.exit(1)

print("Coordination validation PASSED.")
sys.exit(0)
PY
