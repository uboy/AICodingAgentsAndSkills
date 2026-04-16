#!/usr/bin/env bash
set -euo pipefail

# SYNOPSIS
#     Validates coordination artifacts (handoffs, plans) for required sections and format.
#     Follows AGENTS.md Rule 17 (Delivery Contract) and Rule 21 (Orchestration).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
HANDOFFS_DIR="$REPO_ROOT/coordination/handoffs/"
FILES_TO_VALIDATE=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
      HANDOFFS_DIR="$REPO_ROOT/coordination/handoffs/"
      shift 2
      ;;
    --files-to-validate)
      FILES_TO_VALIDATE+=("$2")
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "$HANDOFFS_DIR" ]]; then
  echo "No local handoffs found; nothing to validate."
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

"$PYTHON_BIN" - "$REPO_ROOT" "${FILES_TO_VALIDATE[@]}" <<'PY'
import os
import re
import sys

repo_root = sys.argv[1]
handoffs_dir = os.path.join(repo_root, "coordination/handoffs/")
files_to_validate = sys.argv[2:]
fail_count = 0
strict_commit_readiness = bool(files_to_validate)

if not os.path.exists(handoffs_dir):
    sys.exit(0)

required_sections = [
    r"^## Summary",
    r"^## Files Touched",
    r"^## Verification",
]
# Accept either ## Delivery Contract or ## Commit Message
commit_section_pattern = r"^#{2,3}\s+(Delivery Contract|Commit Message)"

if files_to_validate:
    files = [
        os.path.join(repo_root, rel)
        for rel in files_to_validate
        if rel.startswith("coordination/handoffs/")
        and os.path.exists(os.path.join(repo_root, rel))
    ]
else:
    files = [
        os.path.join(handoffs_dir, filename)
        for filename in os.listdir(handoffs_dir)
        if filename.endswith(".md") and filename != ".gitkeep"
    ]

if files_to_validate and not files:
    print("Requested handoff files were not found.")
    sys.exit(1)

if not files:
    print("No local handoffs found; nothing to validate.")
    sys.exit(0)

for filepath in files:
    filename = os.path.relpath(filepath, repo_root).replace("\\", "/")
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
    verification_match = re.search(r"#{2,3}\s+Verification\s*\n(.*?)(?:\n#{2,3}\s+|$)", content, re.DOTALL)
    if verification_match:
        body = verification_match.group(1).strip()
        if not body or "<command" in body.lower() or body.lower() == "todo":
            print("FAIL: {} has empty or placeholder ## Verification section.".format(filename))
            fail_count += 1
    else:
        print("FAIL: {} could not parse ## Verification section body.".format(filename))
        fail_count += 1

    has_commit_readiness = re.search(r"^#{2,3}\s+Commit Readiness", content, re.MULTILINE)
    readiness_body = ""
    is_ready_to_commit = False
    is_not_commit_ready = False
    if strict_commit_readiness and not has_commit_readiness:
        print("FAIL: {} is missing ## Commit Readiness section.".format(filename))
        fail_count += 1
        continue
    if has_commit_readiness:
        readiness_match = re.search(r"#{2,3}\s+Commit Readiness\s*\n(.*?)(?:\n#{2,3}\s+|$)", content, re.DOTALL)
        if readiness_match:
            readiness_body = readiness_match.group(1).strip()
            if not readiness_body or "todo" in readiness_body.lower() or "<reason" in readiness_body.lower():
                print("FAIL: {} has empty or placeholder ## Commit Readiness section.".format(filename))
                fail_count += 1
                continue
            is_ready_to_commit = bool(re.search(r"(?im)^\s*Ready to commit\.", readiness_body))
            is_not_commit_ready = bool(re.search(r"(?im)^\s*Not commit-ready\.", readiness_body))
            if strict_commit_readiness and not (is_ready_to_commit or is_not_commit_ready):
                print("FAIL: {} must declare either 'Ready to commit.' or 'Not commit-ready.' in ## Commit Readiness.".format(filename))
                fail_count += 1
                continue
        else:
            print("FAIL: {} could not parse ## Commit Readiness section body.".format(filename))
            fail_count += 1
            continue

    # Verify ## Delivery Contract or ## Commit Message is not empty/placeholder
    if not re.search(commit_section_pattern, content, re.MULTILINE):
        print("FAIL: {} is missing ## Delivery Contract or ## Commit Message section.".format(filename))
        fail_count += 1
    else:
        commit_match = re.search(
            r"#{2,3}\s+(?:Delivery Contract|Commit Message)\s*\n(.*?)(?:\n#{2,3}\s+|$)", content, re.DOTALL
        )
        if commit_match:
            body = commit_match.group(1).strip()
            if not body or body.lower() == "todo":
                print("FAIL: {} has empty or placeholder delivery/commit section.".format(filename))
                fail_count += 1
                continue

            if strict_commit_readiness:
                commit_pending = bool(re.search(r"(?i)\bCommit pending user approval\b", body))
                verification_lines = verification_match.group(1).splitlines() if verification_match else []
                has_failed_verification = any(re.search(r"(?i)->\s*fail(?:ed)?\b", line) for line in verification_lines)
                has_security_gate_pass = any(
                    re.search(r"(?i)security-review-gate", line) and re.search(r"(?i)->\s*pass\b", line)
                    for line in verification_lines
                )
                if commit_pending:
                    if not is_ready_to_commit:
                        print("FAIL: {} claims 'Commit pending user approval' without 'Ready to commit.' in ## Commit Readiness.".format(filename))
                        fail_count += 1
                    if has_failed_verification:
                        print("FAIL: {} claims 'Commit pending user approval' but ## Verification contains failed command(s).".format(filename))
                        fail_count += 1
                    if not has_security_gate_pass:
                        print("FAIL: {} claims 'Commit pending user approval' but lacks passing security-review-gate evidence in ## Verification.".format(filename))
                        fail_count += 1

if fail_count > 0:
    print("\nCoordination validation FAILED with {} error(s).".format(fail_count))
    sys.exit(1)

print("Coordination validation PASSED.")
sys.exit(0)
PY
