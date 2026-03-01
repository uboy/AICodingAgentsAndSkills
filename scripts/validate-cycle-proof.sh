#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
CONTRACT_FILE="coordination/cycle-contract.json"
APPROVAL_FILE="coordination/approval-overrides.json"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --repo-root <path>      Override repository root
  --contract-file <path>  Contract file path (default: coordination/cycle-contract.json)
  --approval-file <path>  Approval override file (default: coordination/approval-overrides.json)
  -h, --help              Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
      shift 2
      ;;
    --contract-file)
      CONTRACT_FILE="$2"
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

fail_count=0
warn_count=0
pass_count=0
rows=()

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

CONTRACT_PATH="$REPO_ROOT/$CONTRACT_FILE"
if [[ ! -f "$CONTRACT_PATH" ]]; then
  add_issue "FAIL" "contract-file" "Missing cycle contract file: $CONTRACT_FILE"
else
  add_issue "PASS" "contract-file" "Loaded cycle contract: $CONTRACT_FILE"
fi

PYTHON_BIN=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c "import json,sys" >/dev/null 2>&1; then
    PYTHON_BIN="$candidate"
    break
  fi
done

if [[ -z "$PYTHON_BIN" ]]; then
  add_issue "FAIL" "contract-parse" "python is required to parse $CONTRACT_FILE"
  echo
  echo "Cycle-proof validation report"
  for row in "${rows[@]}"; do
    IFS='|' read -r sev check detail <<< "$row"
    printf "%-6s %-18s %s\n" "$sev" "$check" "$detail"
  done
  echo "Summary: PASS=$pass_count WARN=$warn_count FAIL=$fail_count"
  exit 1
fi

mapfile -t contract_vals < <("$PYTHON_BIN" - "$CONTRACT_PATH" <<'PY'
import json, sys
p = sys.argv[1]
with open(p, "r", encoding="utf-8") as f:
    d = json.load(f)
print(d.get("task_id", ""))
print(d.get("implementation_agent", ""))
print(d.get("review_agent", ""))
print(d.get("required_artifacts", {}).get("review_report", ""))
print(d.get("required_artifacts", {}).get("handoff_report", ""))
print(int(d.get("limits", {}).get("max_functional_files", 0)))
print(int(d.get("limits", {}).get("max_diff_lines", 0)))
for cmd in d.get("required_commands", {}).get("unix", []):
    print("CMD::" + cmd)
PY
)

strip_cr() {
  printf '%s' "$1" | tr -d '\r'
}

task_id="$(strip_cr "${contract_vals[0]:-}")"
impl_agent="$(strip_cr "${contract_vals[1]:-}")"
review_agent="$(strip_cr "${contract_vals[2]:-}")"
review_report_rel="$(strip_cr "${contract_vals[3]:-}")"
handoff_report_rel="$(strip_cr "${contract_vals[4]:-}")"
max_functional_files="$(strip_cr "${contract_vals[5]:-0}")"
max_diff_lines="$(strip_cr "${contract_vals[6]:-0}")"

required_unix_cmds=()
for line in "${contract_vals[@]}"; do
  cleaned_line="$(strip_cr "$line")"
  if [[ "$cleaned_line" == CMD::* ]]; then
    required_unix_cmds+=("${cleaned_line#CMD::}")
  fi
done

for required_field in "$task_id" "$impl_agent" "$review_agent" "$review_report_rel" "$handoff_report_rel"; do
  if [[ -z "$required_field" ]]; then
    add_issue "FAIL" "contract-schema" "Cycle contract has missing required fields."
    break
  fi
done
if [[ ${#required_unix_cmds[@]} -eq 0 ]]; then
  add_issue "FAIL" "contract-schema" "required_commands.unix must contain at least one command."
fi
if [[ ! "$max_functional_files" =~ ^[0-9]+$ ]]; then
  add_issue "FAIL" "contract-schema" "limits.max_functional_files must be a non-negative integer."
  max_functional_files=0
fi
if [[ ! "$max_diff_lines" =~ ^[0-9]+$ ]]; then
  add_issue "FAIL" "contract-schema" "limits.max_diff_lines must be a non-negative integer."
  max_diff_lines=0
fi

changed=()
if git -C "$REPO_ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
  while IFS= read -r line; do changed+=("$line"); done < <(
    {
      git -C "$REPO_ROOT" diff --name-only --diff-filter=ACMRTUXB HEAD
      git -C "$REPO_ROOT" diff --cached --name-only --diff-filter=ACMRTUXB
      git -C "$REPO_ROOT" ls-files --others --exclude-standard
    } | awk 'NF' | sed 's#\\#/#g' | sort -u
  )
else
  while IFS= read -r line; do changed+=("$line"); done < <(
    git -C "$REPO_ROOT" ls-files --others --modified --exclude-standard | awk 'NF' | sed 's#\\#/#g' | sort -u
  )
fi

filtered=()
for rel in "${changed[@]}"; do
  [[ -z "$rel" || "$rel" == fatal:* || "$rel" == warning:* ]] && continue
  filtered+=("$rel")
done
changed=("${filtered[@]}")

functional_patterns=(
  "scripts/*" "policy/*" "configs/*" "deploy/*"
  ".claude/*" ".codex/*" ".gemini/*" ".cursor/*" ".opencode/*"
  ".cursorrules" "AGENTS.md" "AGENTS-hot.md" "AGENTS-warm.md" "AGENTS-cold.md" "AGENTS-hot-warm.md"
  "CLAUDE.md" "CURSOR.md" "GEMINI.md" "OPENCODE.md" "opencode.json" "templates/git/pre-commit"
  "skills/*" "commands/*" "evals/*"
)
non_functional_patterns=(
  "coordination/tasks.jsonl" "coordination/state/*" "coordination/handoffs/*" "coordination/reviews/*" ".scratchpad/*" "coordination/change-scope.txt"
)

matches_any() {
  local rel="$1"; shift
  for p in "$@"; do
    [[ "$rel" == $p ]] && return 0
  done
  return 1
}

functional_changed=()
for rel in "${changed[@]}"; do
  if matches_any "$rel" "${functional_patterns[@]}" && ! matches_any "$rel" "${non_functional_patterns[@]}"; then
    functional_changed+=("$rel")
  fi
done

diff_lines=0
if git -C "$REPO_ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
  while read -r add del _rest; do
    [[ "$add" =~ ^[0-9]+$ ]] && diff_lines=$((diff_lines + add))
    [[ "$del" =~ ^[0-9]+$ ]] && diff_lines=$((diff_lines + del))
  done < <(git -C "$REPO_ROOT" diff --numstat HEAD)
fi
while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  f="$REPO_ROOT/$rel"
  [[ -f "$f" ]] || continue
  count="$(wc -l < "$f" | tr -d ' ')"
  [[ "$count" =~ ^[0-9]+$ ]] && diff_lines=$((diff_lines + count))
done < <(git -C "$REPO_ROOT" ls-files --others --exclude-standard | sed 's#\\#/#g')

allow_large_changes=0
APPROVAL_PATH="$REPO_ROOT/$APPROVAL_FILE"
if [[ -f "$APPROVAL_PATH" ]]; then
  if grep -Eqi '"allow_large_changes"[[:space:]]*:[[:space:]]*true' "$APPROVAL_PATH"; then
    allow_large_changes=1
  fi
fi

functional_count="${#functional_changed[@]}"
if (( functional_count > max_functional_files )); then
  if (( allow_large_changes == 1 )); then
    add_issue "WARN" "iteration-size" "Functional files changed $functional_count > $max_functional_files, allowed by override."
  else
    add_issue "FAIL" "iteration-size" "Functional files changed $functional_count > $max_functional_files. Split task or enable approved override."
  fi
else
  add_issue "PASS" "iteration-size" "Functional files changed $functional_count <= $max_functional_files"
fi

if (( diff_lines > max_diff_lines )); then
  if (( allow_large_changes == 1 )); then
    add_issue "WARN" "diff-size" "Diff lines $diff_lines > $max_diff_lines, allowed by override."
  else
    add_issue "FAIL" "diff-size" "Diff lines $diff_lines > $max_diff_lines. Split task or enable approved override."
  fi
else
  add_issue "PASS" "diff-size" "Diff lines $diff_lines <= $max_diff_lines"
fi

review_report_path="$REPO_ROOT/$(printf '%s' "$review_report_rel" | sed 's#\\#/#g')"
if [[ ! -f "$review_report_path" ]]; then
  add_issue "FAIL" "review-artifact" "Required review report not found: $review_report_rel"
else
  if grep -qF "$task_id" "$review_report_path"; then
    add_issue "PASS" "review-artifact" "Review report references task_id."
  else
    add_issue "FAIL" "review-artifact" "Review report does not reference task_id: $task_id"
  fi

  for cmd in "${required_unix_cmds[@]}"; do
    if ! grep -qF "$cmd" "$review_report_path"; then
      add_issue "FAIL" "review-commands" "Missing required command in review report: $cmd"
    fi
  done

  reviewer="$(sed -n 's/^[[:space:]]*-[[:space:]]*Reviewer:[[:space:]]*\(.*\)$/\1/p' "$review_report_path" | head -n 1)"
  impl="$(sed -n 's/^[[:space:]]*-[[:space:]]*Implementation Agent:[[:space:]]*\(.*\)$/\1/p' "$review_report_path" | head -n 1)"
  if [[ -z "$reviewer" || -z "$impl" ]]; then
    add_issue "FAIL" "independent-review" "Review report must include 'Implementation Agent' and 'Reviewer'."
  elif [[ "$(printf '%s' "$reviewer" | tr '[:upper:]' '[:lower:]')" == "$(printf '%s' "$impl" | tr '[:upper:]' '[:lower:]')" ]]; then
    add_issue "FAIL" "independent-review" "Reviewer must differ from implementation agent."
  else
    add_issue "PASS" "independent-review" "Reviewer and implementation agent differ."
  fi
fi

handoff_report_path="$REPO_ROOT/$(printf '%s' "$handoff_report_rel" | sed 's#\\#/#g')"
if [[ -f "$handoff_report_path" ]]; then
  add_issue "PASS" "handoff-artifact" "Handoff report found."
else
  add_issue "FAIL" "handoff-artifact" "Required handoff report not found: $handoff_report_rel"
fi

echo
echo "Cycle-proof validation report"
echo "Repo: $REPO_ROOT"
echo "Contract: $CONTRACT_FILE"
echo
printf "%-6s %-18s %s\n" "SEV" "CHECK" "DETAIL"
printf "%-6s %-18s %s\n" "---" "-----" "------"
for row in "${rows[@]}"; do
  IFS='|' read -r sev check detail <<< "$row"
  printf "%-6s %-18s %s\n" "$sev" "$check" "$detail"
done
echo
echo "Summary: PASS=$pass_count WARN=$warn_count FAIL=$fail_count"

if (( fail_count > 0 )); then
  exit 1
fi
exit 0
