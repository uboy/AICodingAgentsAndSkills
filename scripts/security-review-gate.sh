#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --repo-root <path>   Override repository root
  -h, --help           Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
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

mapfile -t changed < <(
  {
    git -C "$REPO_ROOT" diff --name-only --diff-filter=ACMRTUXB HEAD
    git -C "$REPO_ROOT" diff --cached --name-only --diff-filter=ACMRTUXB
  } | awk 'NF' | sort -u
)

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

if [[ ${#changed[@]} -eq 0 ]]; then
  add_issue "WARN" "changed-files" "No changed files detected against HEAD."
fi

skills_changed=0
secret_pattern='(api[_-]?key|secret|token|password)[[:space:]]*[:=][[:space:]]*["'\''][^"'\'']{8,}["'\'']|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}'
placeholder_pattern='(example|sample|dummy|test|changeme|<token>|<secret>|<password>)'

# Collect file lists for batch operations (one pass through changed[])
declare -a conflict_paths=()  # files to check for conflict markers
declare -a scan_paths=()       # files to secret-scan (non-md)

for rel in "${changed[@]}"; do
  path="$REPO_ROOT/$rel"
  [[ -f "$path" ]] || continue

  # Skills detection
  [[ "$rel" == skills/* ]] && skills_changed=1

  # Collect for conflict-marker batch check
  if [[ "$rel" != "scripts/install.sh" && "$rel" != "scripts/install.ps1" ]]; then
    conflict_paths+=("$path")
  fi

  # Collect for secret-scan batch check (skip Markdown)
  [[ "$rel" == *.md ]] || scan_paths+=("$path")

  # Shell syntax check (fast, per-file bash built-in)
  if [[ "$rel" == *.sh ]]; then
    if ! bash -n "$path" >/dev/null 2>&1; then
      add_issue "FAIL" "bash-parse" "bash -n failed for $rel"
    fi
  fi
done

# Batch conflict-marker check (one grep over all files)
if [[ ${#conflict_paths[@]} -gt 0 ]]; then
  while IFS= read -r matched_path; do
    [[ -n "$matched_path" ]] || continue
    rel="${matched_path#$REPO_ROOT/}"
    add_issue "FAIL" "merge-markers" "Conflict markers found in $rel"
  done < <(grep -lE '^(<<<<<<<|=======|>>>>>>>)' "${conflict_paths[@]}" 2>/dev/null || true)
fi

# Batch secret scan (one grep over all non-md files, then placeholder filter per hit)
if [[ ${#scan_paths[@]} -gt 0 ]]; then
  while IFS=: read -r matched_path line_no line_text; do
    [[ -n "$line_no" ]] || continue
    if ! printf '%s' "$line_text" | grep -Eiq "$placeholder_pattern"; then
      rel="${matched_path#$REPO_ROOT/}"
      add_issue "FAIL" "secret-scan" "Possible secret in $rel:$line_no"
    fi
  done < <(grep -EniH "$secret_pattern" "${scan_paths[@]}" 2>/dev/null || true)
fi

# Coordination check
coordination_changed=($(printf "%s\n" "${changed[@]}" | grep -E '^coordination/(handoffs/|state/)' || true))
if [[ ${#coordination_changed[@]} -gt 0 ]]; then
  if [[ -f "$REPO_ROOT/scripts/validate-coordination.sh" ]]; then
    if ! bash "$REPO_ROOT/scripts/validate-coordination.sh" >/dev/null 2>&1; then
      add_issue "FAIL" "coordination-validate" "Coordination artifact validation failed."
    fi
  else
    add_issue "WARN" "coordination-validate" "validate-coordination.sh not found; skipped."
  fi
fi

# Skills validation
if [[ $skills_changed -eq 1 ]]; then
  if [[ -f "$REPO_ROOT/scripts/validate-skills.sh" ]]; then
    if ! bash "$REPO_ROOT/scripts/validate-skills.sh" >/dev/null; then
      add_issue "FAIL" "skills-validate" "Skill validation failed."
    fi
  else
    add_issue "WARN" "skills-validate" "validate-skills.sh not found; skipped."
  fi
fi

# Integrity check (using our robust script)
if [[ -f "$REPO_ROOT/scripts/run-integrity-fast.sh" ]]; then
  if ! bash "$REPO_ROOT/scripts/run-integrity-fast.sh" >/dev/null 2>&1; then
    add_issue "FAIL" "integrity-fast" "run-integrity-fast.sh failed."
  fi
else
  add_issue "WARN" "integrity-fast" "scripts/run-integrity-fast.sh not found."
fi

if [[ ${#rows[@]} -eq 0 ]]; then
  add_issue "PASS" "gate" "No issues detected."
fi

echo
echo "Security review gate report"
echo "Repo: $REPO_ROOT"
echo "Changed files: ${#changed[@]}"
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
