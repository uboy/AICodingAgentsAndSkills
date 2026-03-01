#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
REVIEWS_DIR="$REPO_ROOT/coordination/reviews"

if [[ ! -d "$REVIEWS_DIR" ]]; then
  echo "Missing coordination/reviews directory." >&2
  exit 1
fi

run_shell_fallback() {
  fail_count=0
  files=()
  while IFS= read -r file; do
    files+=("$file")
  done < <(find "$REVIEWS_DIR" -maxdepth 1 -type f -name "*.md" ! -name ".gitkeep" | sort)

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No review report files found." >&2
    return 1
  fi

  for path in "${files[@]}"; do
    rel="${path#$REPO_ROOT/}"
    for header in "## Scope" "## Findings" "## Verification" "## Residual Risks" "## Approval"; do
      if ! grep -q "^${header}$" "$path"; then
        echo "FAIL: $rel missing section: $header"
        fail_count=$((fail_count + 1))
      fi
    done

    for section in "Findings" "Verification" "Approval"; do
      body="$(
        awk -v sec="## ${section}" '
          $0 == sec {in=1; next}
          in && /^## / {exit}
          in {print}
        ' "$path"
      )"
      trimmed="$(printf "%s" "$body" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
      if [[ -z "$trimmed" ]] || printf "%s" "$trimmed" | grep -Eiq '\b(todo|tbd|<placeholder>)\b'; then
        echo "FAIL: $rel has empty or placeholder ## $section"
        fail_count=$((fail_count + 1))
      fi
    done

    impl="$(sed -n 's/^[[:space:]]*-[[:space:]]*Implementation Agent:[[:space:]]*\(.*\)$/\1/p' "$path" | head -n 1)"
    reviewer="$(sed -n 's/^[[:space:]]*-[[:space:]]*Reviewer:[[:space:]]*\(.*\)$/\1/p' "$path" | head -n 1)"
    if [[ -z "$impl" || -z "$reviewer" ]]; then
      echo "FAIL: $rel must include both '- Implementation Agent:' and '- Reviewer:' in ## Approval."
      fail_count=$((fail_count + 1))
    elif [[ "$(printf '%s' "$impl" | tr '[:upper:]' '[:lower:]')" == "$(printf '%s' "$reviewer" | tr '[:upper:]' '[:lower:]')" ]]; then
      echo "FAIL: $rel reviewer must differ from implementation agent."
      fail_count=$((fail_count + 1))
    fi
  done

  if [[ $fail_count -gt 0 ]]; then
    echo
    echo "Review report validation FAILED with $fail_count error(s)."
    return 1
  fi
  echo "Review report validation PASSED."
  return 0
}

PYTHON_BIN=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1; then
    if "$candidate" -c "import sys" >/dev/null 2>&1; then
      PYTHON_BIN="$candidate"
      break
    fi
  fi
done

if [[ -z "$PYTHON_BIN" ]]; then
  run_shell_fallback
  exit $?
fi

"$PYTHON_BIN" - "$REPO_ROOT" <<'PY'
import os
import re
import sys

repo_root = sys.argv[1]
reviews_dir = os.path.join(repo_root, "coordination", "reviews")

required = ["## Scope", "## Findings", "## Verification", "## Residual Risks", "## Approval"]
fail_count = 0
files = []
for name in os.listdir(reviews_dir):
    if name.endswith(".md") and name != ".gitkeep":
        files.append(os.path.join(reviews_dir, name))

if not files:
    print("No review report files found.", file=sys.stderr)
    sys.exit(1)

for path in files:
    rel = os.path.relpath(path, repo_root).replace("\\", "/")
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    missing = [s for s in required if s not in content]
    if missing:
        print("FAIL: {} missing section(s): {}".format(rel, ", ".join(missing)))
        fail_count += 1
        continue

    for section in ["Findings", "Verification", "Approval"]:
        m = re.search(r"## {}\s*\n(.*?)(?:\n##|$)".format(re.escape(section)), content, re.DOTALL)
        if not m:
            print("FAIL: {} could not parse ## {}".format(rel, section))
            fail_count += 1
            continue
        body = m.group(1).strip()
        if (not body) or re.search(r"\b(todo|tbd|<placeholder>)\b", body, flags=re.IGNORECASE):
            print("FAIL: {} has empty or placeholder ## {}".format(rel, section))
            fail_count += 1

    impl_match = re.search(r"(?im)^\s*-\s*Implementation Agent:\s*(.+)\s*$", content)
    reviewer_match = re.search(r"(?im)^\s*-\s*Reviewer:\s*(.+)\s*$", content)
    if not impl_match or not reviewer_match:
        print("FAIL: {} must include both '- Implementation Agent:' and '- Reviewer:' in ## Approval.".format(rel))
        fail_count += 1
    else:
        impl = impl_match.group(1).strip().lower()
        reviewer = reviewer_match.group(1).strip().lower()
        if impl == reviewer:
            print("FAIL: {} reviewer must differ from implementation agent.".format(rel))
            fail_count += 1

if fail_count > 0:
    print("\nReview report validation FAILED with {} error(s).".format(fail_count))
    sys.exit(1)

print("Review report validation PASSED.")
sys.exit(0)
PY
