#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# Basenames intentionally allowed to exist on one platform only.
IGNORE_BASENAMES=(
)

fail_count=0
warn_count=0

add_result() {
  local severity="$1"
  local check="$2"
  local detail="$3"
  printf "%s %s %s\n" "$severity" "$check" "$detail"
  case "$severity" in
    FAIL) fail_count=$((fail_count + 1)) ;;
    WARN) warn_count=$((warn_count + 1)) ;;
  esac
}

contains_ignore() {
  local needle="$1"
  local item
  for item in "${IGNORE_BASENAMES[@]}"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

if [[ ! -d "$REPO_ROOT/scripts" ]]; then
  add_result "FAIL" "scripts-dir" "Scripts directory not found: $REPO_ROOT/scripts"
  echo "Summary: PASS=0 WARN=$warn_count FAIL=$fail_count"
  exit 1
fi

declare -A ps_names=()
declare -A sh_names=()

for path in "$REPO_ROOT/scripts"/*.ps1; do
  [[ -f "$path" ]] || continue
  name="${path%.ps1}"; name="${name##*/}"
  ps_names["$name"]=1
done

for path in "$REPO_ROOT/scripts"/*.sh; do
  [[ -f "$path" ]] || continue
  name="${path%.sh}"; name="${name##*/}"
  sh_names["$name"]=1
done

for name in "${!ps_names[@]}"; do
  if contains_ignore "$name"; then
    continue
  fi
  if [[ -z "${sh_names[$name]:-}" ]]; then
    add_result "FAIL" "script-parity" "Missing scripts/$name.sh (paired with scripts/$name.ps1)"
  fi
done

for name in "${!sh_names[@]}"; do
  if contains_ignore "$name"; then
    continue
  fi
  if [[ -z "${ps_names[$name]:-}" ]]; then
    add_result "FAIL" "script-parity" "Missing scripts/$name.ps1 (paired with scripts/$name.sh)"
  fi
done

adapter_files=(
  "CLAUDE.md"
  ".codex/AGENTS.md"
  "CURSOR.md"
      "GEMINI.md"
      "OPENCODE.md"
      ".opencode/AGENTS.md"
      ".gemini/AGENTS.md"
  )

adapter_line_limit() {
  local rel="$1"
  case "$rel" in
    ".codex/AGENTS.md") echo "1000" ;;
    *) echo "40" ;;
  esac
}

  for rel in "${adapter_files[@]}"; do
  path="$REPO_ROOT/$rel"
  if [[ ! -f "$path" ]]; then
    add_result "FAIL" "adapter-presence" "Missing required adapter file: $rel"
    continue
  fi

  line_count="$(wc -l < "$path" | tr -d ' ')"
  if ! grep -qE "AGENTS(-hot|-warm|-cold|-hot-warm)?\.md" "$path"; then
    add_result "FAIL" "adapter-thin" "$rel must reference AGENTS.md (or a tier file: AGENTS-hot.md, AGENTS-warm.md, etc.)"
  fi
  line_limit="$(adapter_line_limit "$rel")"
  if [[ "$line_count" -gt "$line_limit" ]]; then
    add_result "FAIL" "adapter-thin" "$rel has $line_count lines; expected <= $line_limit"
  fi
done

if [[ $fail_count -eq 0 ]]; then
  add_result "PASS" "parity" "Cross-OS and cross-system parity checks passed."
fi

if [[ $fail_count -eq 0 ]]; then
  pass_count=1
else
  pass_count=0
fi
echo "Summary: PASS=$pass_count WARN=$warn_count FAIL=$fail_count"

if [[ $fail_count -gt 0 ]]; then
  exit 1
fi
exit 0
