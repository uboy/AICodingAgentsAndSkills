#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SKILLS_ROOT="$REPO_ROOT/skills"
EVALS_ROOT="$REPO_ROOT/evals/skills/cases"

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
      SKILLS_ROOT="$REPO_ROOT/skills"
      EVALS_ROOT="$REPO_ROOT/evals/skills/cases"
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

if [[ ! -d "$SKILLS_ROOT" ]]; then
  echo "Skills directory not found: $SKILLS_ROOT" >&2
  exit 1
fi

SKILL_FILES=()
for f in "$SKILLS_ROOT"/*/SKILL.md; do
  [[ -f "$f" ]] && SKILL_FILES+=("$f")
done
if [[ ${#SKILL_FILES[@]} -eq 0 ]]; then
  echo "No SKILL.md files found under: $SKILLS_ROOT" >&2
  exit 1
fi

fail_count=0

echo
echo "Skill validation report"
echo "Repo: $REPO_ROOT"
echo
printf "%-25s %-8s %s\n" "SKILL" "STATUS" "DETAIL"
printf "%-25s %-8s %s\n" "-----" "------" "------"

# Single-pass awk that checks ALL structural requirements in one process per file
_check_skill_file() {
  awk '
    BEGIN {
      in_fm=0; fm_opened=0; fm_closed=0
      has_name=0; has_desc=0
      has_skill_header=0; has_purpose=0; has_input=0; has_output=0; has_safety=0
      detail=""
    }
    NR==1 {
      if ($0 ~ /^---[[:space:]]*$/) { in_fm=1; fm_opened=1 }
      else { detail=detail "Missing YAML frontmatter. " }
      next
    }
    in_fm && $0 ~ /^---[[:space:]]*$/ { in_fm=0; fm_closed=1; next }
    in_fm {
      if ($0 ~ /^name:[[:space:]]+[^[:space:]]/) has_name=1
      if ($0 ~ /^description:[[:space:]]+[^[:space:]]/) has_desc=1
      next
    }
    $0 ~ /^# Skill:[[:space:]]+[^[:space:]]/ { has_skill_header=1 }
    $0 ~ /^## Purpose[[:space:]]*$/           { has_purpose=1 }
    $0 ~ /^## Input[[:space:]]*$/             { has_input=1 }
    $0 ~ /^## (Output Format|Mode Contracts)[[:space:]]*$/ || $0 ~ /^Output:[[:space:]]*$/ { has_output=1 }
    $0 ~ /^## (Shared Safety|Safety Rules|Global Safety Rules|Global Processing Rules)[[:space:]]*$/ { has_safety=1 }
    END {
      if (fm_opened && !fm_closed) detail=detail "YAML frontmatter not closed. "
      if (fm_opened && fm_closed) {
        if (!has_name)  detail=detail "Frontmatter missing required '"'"'name'"'"' field. "
        if (!has_desc)  detail=detail "Frontmatter missing required '"'"'description'"'"' field. "
      }
      if (!has_skill_header) detail=detail "Missing '"'"'# Skill:'"'"' header. "
      if (!has_purpose)      detail=detail "Missing '"'"'## Purpose'"'"' section. "
      if (!has_input)        detail=detail "Missing '"'"'## Input'"'"' section. "
      if (!has_output)       detail=detail "Missing output contract section. "
      if (!has_safety)       detail=detail "Missing safety section. "
      print detail
      exit (detail != "" ? 1 : 0)
    }
  ' "$1"
}

for file in "${SKILL_FILES[@]}"; do
  skill_name="$(basename "$(dirname "$file")")"
  detail="$(_check_skill_file "$file" || true)"

  if [[ "$skill_name" != _* ]]; then
    eval_case="$EVALS_ROOT/$skill_name.md"
    [[ -f "$eval_case" ]] || detail+="Missing eval case: evals/skills/cases/$skill_name.md "
  fi

  if [[ -z "$detail" ]]; then
    printf "%-25s %-8s %s\n" "$skill_name" "PASS" "Structure checks passed."
  else
    printf "%-25s %-8s %s\n" "$skill_name" "FAIL" "$detail"
    fail_count=$((fail_count + 1))
  fi
done

echo
if [[ $fail_count -gt 0 ]]; then
  echo "Validation failed: $fail_count skill(s) have issues."
  exit 1
fi
echo "Validation passed."
