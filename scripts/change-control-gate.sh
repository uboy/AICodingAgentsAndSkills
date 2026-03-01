#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SCOPE_FILE="coordination/change-scope.txt"
APPROVAL_FILE="coordination/approval-overrides.json"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --repo-root <path>     Override repository root
  --scope-file <path>    Scope file path (default: coordination/change-scope.txt)
  --approval-file <path> Approval override file (default: coordination/approval-overrides.json)
  -h, --help             Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
      shift 2
      ;;
    --scope-file)
      SCOPE_FILE="$2"
      shift 2
      ;;
    --approval-file)
      APPROVAL_FILE="$2"
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

if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: Not a git repository: $REPO_ROOT" >&2
  exit 1
fi

changed=()
if git -C "$REPO_ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
  while IFS= read -r line; do
    changed+=("$line")
  done < <(
    {
      git -C "$REPO_ROOT" diff --name-only --diff-filter=ACMRTUXB HEAD
      git -C "$REPO_ROOT" diff --cached --name-only --diff-filter=ACMRTUXB
      git -C "$REPO_ROOT" ls-files --others --exclude-standard
    } | awk 'NF' | sed 's#\\#/#g' | sort -u
  )
else
  while IFS= read -r line; do
    changed+=("$line")
  done < <(git -C "$REPO_ROOT" ls-files --others --modified --exclude-standard | awk 'NF' | sed 's#\\#/#g' | sort -u)
fi

filtered=()
for rel in "${changed[@]}"; do
  [[ -z "$rel" ]] && continue
  [[ "$rel" == fatal:* ]] && continue
  [[ "$rel" == warning:* ]] && continue
  filtered+=("$rel")
done
changed=("${filtered[@]}")

fail_count=0
warn_count=0
pass_count=0
declare -a rows=()

add_issue() {
  local severity="$1"
  local check="$2"
  local detail="$3"
  rows+=("$severity|$check|$detail")
  case "$severity" in
    FAIL) fail_count=$((fail_count + 1)) ;;
    WARN) warn_count=$((warn_count + 1)) ;;
    PASS) pass_count=$((pass_count + 1)) ;;
  esac
}

matches_any() {
  local rel="$1"
  shift
  local pattern
  for pattern in "$@"; do
    [[ -z "$pattern" ]] && continue
    if [[ "$rel" == $pattern ]]; then
      return 0
    fi
  done
  return 1
}

if [[ ${#changed[@]} -eq 0 ]]; then
  add_issue "WARN" "changed-files" "No changed files detected against HEAD."
fi

scope_rel="$(printf '%s' "$SCOPE_FILE" | sed 's#\\#/#g' | sed 's#^/##')"
scope_path="$REPO_ROOT/$scope_rel"
approval_rel="$(printf '%s' "$APPROVAL_FILE" | sed 's#\\#/#g' | sed 's#^/##')"
approval_path="$REPO_ROOT/$approval_rel"
declare -a scope_patterns=()

if [[ ! -f "$scope_path" ]]; then
  add_issue "FAIL" "scope-file" "Missing scope file: $scope_rel. Create it from coordination/templates/change-scope.txt."
else
  while IFS= read -r line; do
    trimmed="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    [[ -z "$trimmed" ]] && continue
    [[ "${trimmed:0:1}" == "#" ]] && continue
    scope_patterns+=("$(printf '%s' "$trimmed" | sed 's#\\#/#g' | sed 's#^/##')")
  done < "$scope_path"

  if [[ ${#scope_patterns[@]} -eq 0 ]]; then
    add_issue "FAIL" "scope-file" "Scope file is empty: $scope_rel"
  else
    add_issue "PASS" "scope-file" "Loaded ${#scope_patterns[@]} scope pattern(s) from $scope_rel"
  fi
fi

always_allowed=(
  "$scope_rel"
  "$approval_rel"
  "coordination/tasks.jsonl"
  "coordination/state/*"
  "coordination/handoffs/*"
  "coordination/reviews/*"
  "coordination/templates/approval-overrides.json"
  ".scratchpad/*"
)

declare -a out_of_scope=()
if [[ ${#scope_patterns[@]} -gt 0 && ${#changed[@]} -gt 0 ]]; then
  for rel in "${changed[@]}"; do
    if matches_any "$rel" "${always_allowed[@]}"; then
      continue
    fi
    if matches_any "$rel" "${scope_patterns[@]}"; then
      continue
    fi
    out_of_scope+=("$rel")
  done
fi

if [[ ${#out_of_scope[@]} -gt 0 ]]; then
  add_issue "FAIL" "scope-drift" "Out-of-scope changes: $(IFS=', '; echo "${out_of_scope[*]}")"
elif [[ ${#changed[@]} -gt 0 && ${#scope_patterns[@]} -gt 0 ]]; then
  add_issue "PASS" "scope-drift" "All changed files are within declared scope."
fi

functional_patterns=(
  "scripts/*"
  "policy/*"
  "configs/*"
  "deploy/*"
  ".claude/*"
  ".codex/*"
  ".gemini/*"
  ".cursor/*"
  ".opencode/*"
  ".cursorrules"
  "AGENTS.md"
  "AGENTS-hot.md"
  "AGENTS-warm.md"
  "AGENTS-cold.md"
  "AGENTS-hot-warm.md"
  "CLAUDE.md"
  "CURSOR.md"
  "GEMINI.md"
  "OPENCODE.md"
  "opencode.json"
  "templates/git/pre-commit"
)

functional_changed=0
for rel in "${changed[@]}"; do
  if matches_any "$rel" "${always_allowed[@]}"; then
    continue
  fi
  if matches_any "$rel" "${functional_patterns[@]}"; then
    functional_changed=1
    break
  fi
done

if [[ $functional_changed -eq 1 ]]; then
  docs_patterns=(
    "README.md"
    "policy/*.md"
    "coordination/PLAN-TASK-PROTOCOL.md"
    "coordination/templates/*"
    "docs/*"
    "SPEC.md"
  )

  has_docs=0
  has_tasks=0
  has_handoff_in_changes=0
  has_handoff_file=0
  has_handoff=0
  has_review=0
  for rel in "${changed[@]}"; do
    if matches_any "$rel" "${docs_patterns[@]}"; then
      has_docs=1
    fi
    if [[ "$rel" == "coordination/tasks.jsonl" ]]; then
      has_tasks=1
    fi
    if [[ "$rel" == coordination/handoffs/*.md ]]; then
      has_handoff_in_changes=1
    fi
    if [[ "$rel" == coordination/reviews/*.md && "$rel" != "coordination/reviews/.gitkeep" ]]; then
      has_review=1
    fi
  done

  if [[ -d "$REPO_ROOT/coordination/handoffs" ]]; then
    if find "$REPO_ROOT/coordination/handoffs" -maxdepth 1 -type f -name "*.md" ! -name ".gitkeep" | grep -q .; then
      has_handoff_file=1
    fi
  fi
  if [[ $has_handoff_in_changes -eq 1 || $has_handoff_file -eq 1 ]]; then
    has_handoff=1
  fi

  if [[ $has_docs -eq 1 ]]; then
    add_issue "PASS" "docs-contract" "Functional changes include docs/policy updates."
  else
    add_issue "FAIL" "docs-contract" "Functional changes detected without docs/policy update."
  fi

  if [[ $has_tasks -eq 1 ]]; then
    add_issue "PASS" "tasks-checklist" "coordination/tasks.jsonl updated."
  else
    add_issue "FAIL" "tasks-checklist" "Functional changes detected without coordination/tasks.jsonl update."
  fi

  if [[ $has_handoff -eq 1 ]]; then
    add_issue "PASS" "handoff-evidence" "Handoff evidence detected."
  else
    add_issue "FAIL" "handoff-evidence" "Functional changes detected without coordination/handoffs/*.md update."
  fi

  if [[ $has_review -eq 1 ]]; then
    if [[ -f "$REPO_ROOT/scripts/validate-review-report.sh" ]]; then
      if bash "$REPO_ROOT/scripts/validate-review-report.sh" >/dev/null 2>&1; then
        add_issue "PASS" "review-pipeline" "Review report present and valid."
      else
        add_issue "FAIL" "review-pipeline" "Review report validation failed."
      fi
    else
      add_issue "FAIL" "review-pipeline" "scripts/validate-review-report.sh not found."
    fi
  else
    add_issue "FAIL" "review-pipeline" "Functional changes detected without coordination/reviews/*.md report."
  fi
else
  add_issue "PASS" "docs-contract" "No functional changes requiring docs/checklist/handoff contract."
fi

allow_existing_test_modifications=0
allow_architecture_changes=0
approved_by=""
reason=""
if [[ -f "$approval_path" ]]; then
  PYTHON_BIN=""
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then
      if "$candidate" -c "import json,sys" >/dev/null 2>&1; then
        PYTHON_BIN="$candidate"
        break
      fi
    fi
  done

  if [[ "$PYTHON_BIN" == "python3" ]]; then
    approval_vals=()
    while IFS= read -r line; do
      approval_vals+=("$line")
    done < <("$PYTHON_BIN" - "$approval_path" <<'PY'
import json, sys
p = sys.argv[1]
with open(p, "r", encoding="utf-8") as f:
    d = json.load(f)
print("1" if d.get("allow_existing_test_modifications") else "0")
print("1" if d.get("allow_architecture_changes") else "0")
print(str(d.get("approved_by", "")))
print(str(d.get("reason", "")))
PY
)
  elif [[ "$PYTHON_BIN" == "python" ]]; then
    approval_vals=()
    while IFS= read -r line; do
      approval_vals+=("$line")
    done < <("$PYTHON_BIN" - "$approval_path" <<'PY'
import json, sys
p = sys.argv[1]
with open(p, "r", encoding="utf-8") as f:
    d = json.load(f)
print("1" if d.get("allow_existing_test_modifications") else "0")
print("1" if d.get("allow_architecture_changes") else "0")
print(str(d.get("approved_by", "")))
print(str(d.get("reason", "")))
PY
)
  else
    # Fallback parser keeps strict defaults and avoids hard dependency on python.
    if grep -Eqi '"allow_existing_test_modifications"[[:space:]]*:[[:space:]]*true' "$approval_path"; then
      allow_existing_test_modifications=1
    fi
    if grep -Eqi '"allow_architecture_changes"[[:space:]]*:[[:space:]]*true' "$approval_path"; then
      allow_architecture_changes=1
    fi
    approved_by="$(sed -n 's/.*"approved_by"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$approval_path" | head -n 1)"
    reason="$(sed -n 's/.*"reason"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$approval_path" | head -n 1)"
    add_issue "WARN" "approval-file" "python not found; used fallback parser for $approval_rel"
    approval_vals=("fallback" "fallback" "fallback" "fallback")
  fi

  if [[ ${#approval_vals[@]} -ge 4 ]]; then
    if [[ "${approval_vals[0]}" != "fallback" ]]; then
      allow_existing_test_modifications="${approval_vals[0]}"
      allow_architecture_changes="${approval_vals[1]}"
      approved_by="${approval_vals[2]}"
      reason="${approval_vals[3]}"
      add_issue "PASS" "approval-file" "Loaded override controls from $approval_rel"
    fi
  elif [[ ${#approval_vals[@]} -gt 0 ]]; then
    add_issue "FAIL" "approval-file" "Invalid JSON in $approval_rel"
  fi
else
  add_issue "PASS" "approval-file" "No override file detected ($approval_rel); strict defaults active."
fi

status_lines=()
while IFS= read -r line; do
  status_lines+=("$line")
done < <(git -C "$REPO_ROOT" status --porcelain | awk 'NF')
test_patterns=("tests/*" "evals/*" "*.test.ps1" "*.test.sh" "*.spec.*")
arch_patterns=("docs/design/*" "docs/architecture/*" "ARCHITECTURE.md" "SPEC.md")
declare -a existing_tests_touched=()
declare -a existing_arch_touched=()

for line in "${status_lines[@]}"; do
  [[ ${#line} -lt 4 ]] && continue
  xy="${line:0:2}"
  path_part="${line:3}"
  if [[ "$path_part" == *" -> "* ]]; then
    path_part="${path_part##* -> }"
  fi
  rel="$(printf '%s' "$path_part" | sed 's#\\#/#g' | sed 's#^/##')"
  [[ -z "$rel" ]] && continue

  is_new=0
  [[ "$xy" == "??" ]] && is_new=1
  [[ "${xy:0:1}" == "A" ]] && is_new=1
  [[ "${xy:1:1}" == "A" ]] && is_new=1
  [[ $is_new -eq 1 ]] && continue

  if matches_any "$rel" "${test_patterns[@]}"; then
    existing_tests_touched+=("$rel")
  fi
  if matches_any "$rel" "${arch_patterns[@]}"; then
    existing_arch_touched+=("$rel")
  fi
done

if [[ ${#existing_tests_touched[@]} -gt 0 ]]; then
  uniq_tests="$(printf "%s\n" "${existing_tests_touched[@]}" | sort -u | paste -sd ', ' -)"
  if [[ "$allow_existing_test_modifications" == "1" ]]; then
    add_issue "WARN" "test-freeze" "Existing tests modified with override approval ($approved_by): $uniq_tests"
  else
    add_issue "FAIL" "test-freeze" "Existing tests modified without approval override: $uniq_tests"
  fi
else
  add_issue "PASS" "test-freeze" "No existing tests were modified."
fi

if [[ ${#existing_arch_touched[@]} -gt 0 ]]; then
  uniq_arch="$(printf "%s\n" "${existing_arch_touched[@]}" | sort -u | paste -sd ', ' -)"
  if [[ "$allow_architecture_changes" == "1" ]]; then
    add_issue "WARN" "arch-freeze" "Architecture/design files modified with override approval ($approved_by): $uniq_arch"
  else
    add_issue "FAIL" "arch-freeze" "Architecture/design files modified without approval override: $uniq_arch"
  fi
else
  add_issue "PASS" "arch-freeze" "No existing architecture/design files were modified."
fi

echo
echo "Change-control gate report"
echo "Repo: $REPO_ROOT"
echo "Changed files: ${#changed[@]}"
echo "Scope file: $scope_rel"
echo
printf "%-6s %-16s %s\n" "SEV" "CHECK" "DETAIL"
printf "%-6s %-16s %s\n" "---" "-----" "------"
for row in "${rows[@]}"; do
  IFS='|' read -r sev check detail <<< "$row"
  printf "%-6s %-16s %s\n" "$sev" "$check" "$detail"
done
echo
echo "Summary: PASS=$pass_count WARN=$warn_count FAIL=$fail_count"

if [[ $fail_count -gt 0 ]]; then
  exit 1
fi
exit 0
