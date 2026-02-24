#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
MANIFEST_PATH="$REPO_ROOT/deploy/manifest.txt"
HOME_DIR="${HOME:-$(cd ~ && pwd -P)}"

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
      MANIFEST_PATH="$REPO_ROOT/deploy/manifest.txt"
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

if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "Manifest not found: $MANIFEST_PATH" >&2
  exit 1
fi

abspath() {
  local p="$1"
  local dir
  dir="$(cd "$(dirname "$p")" && pwd -P)"
  echo "$dir/$(basename "$p")"
}

resolve_link_target() {
  local target="$1"
  local link
  link="$(readlink "$target" || true)"
  if [[ -z "$link" ]]; then
    return 1
  fi
  if [[ "$link" = /* ]]; then
    echo "$link"
  else
    abspath "$(dirname "$target")/$link"
  fi
}

same_content() {
  local a="$1"
  local b="$2"
  cmp -s "$a" "$b"
}

declare -a RESULTS=()
declare -A STATUS_COUNT=()

add_result() {
  local status="$1"
  local kind="$2"
  local source="$3"
  local target="$4"
  local detail="$5"
  RESULTS+=("$status|$kind|$source|$target|$detail")
  STATUS_COUNT["$status"]=$(( ${STATUS_COUNT["$status"]:-0} + 1 ))
}

audit_file() {
  local source_file="$1"
  local target_file="$2"
  local kind="$3"

  if [[ ! -f "$source_file" ]]; then
    add_result "SOURCE-MISSING" "$kind" "$source_file" "$target_file" "Source file not found in repo."
    return
  fi

  if [[ ! -f "$target_file" ]]; then
    add_result "MISSING" "$kind" "$source_file" "$target_file" "Target file not found in home."
    return
  fi

  if [[ -L "$target_file" ]]; then
    local linked
    linked="$(resolve_link_target "$target_file" || true)"
    if [[ -n "$linked" && "$(abspath "$source_file")" == "$(abspath "$linked")" ]]; then
      add_result "OK-LINKED" "$kind" "$source_file" "$target_file" "Target points to repo source."
      return
    fi
  fi

  if same_content "$source_file" "$target_file"; then
    add_result "OK-EQUAL" "$kind" "$source_file" "$target_file" "Content matches source."
    return
  fi

  add_result "DIFFERENT" "$kind" "$source_file" "$target_file" "Content differs from source."
}

while IFS='|' read -r source_rel target_rel; do
  line="${source_rel}${target_rel}"
  if [[ -z "${line// }" ]]; then
    continue
  fi
  [[ "${source_rel#"${source_rel%%[![:space:]]*}"}" == \#* ]] && continue
  source_rel="$(echo "$source_rel" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  target_rel="$(echo "$target_rel" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -z "$source_rel" || -z "$target_rel" ]] && continue

  source_path="$REPO_ROOT/$source_rel"
  target_path="$HOME_DIR/$target_rel"

  if [[ ! -e "$source_path" ]]; then
    add_result "SOURCE-MISSING" "entry" "$source_path" "$target_path" "Manifest source entry is missing."
    continue
  fi

  if [[ -f "$source_path" ]]; then
    audit_file "$source_path" "$target_path" "file"
    continue
  fi

  if [[ -d "$source_path" ]]; then
    declare -A SRC_REL=()
    while IFS= read -r src_file; do
      rel="${src_file#"$source_path"/}"
      SRC_REL["$rel"]=1
      audit_file "$src_file" "$target_path/$rel" "dir-file"
    done < <(find "$source_path" -type f)

    if [[ -d "$target_path" ]]; then
      while IFS= read -r tgt_file; do
        rel="${tgt_file#"$target_path"/}"
        if [[ -z "${SRC_REL["$rel"]+x}" ]]; then
          add_result "EXTRA" "dir-extra" "(none)" "$tgt_file" "Present in target directory only."
        fi
      done < <(find "$target_path" -type f)
    elif [[ -f "$target_path" ]]; then
      add_result "DIFFERENT" "entry" "$source_path" "$target_path" "Target path is file but source path is directory."
    fi
  fi
done < "$MANIFEST_PATH"

echo
echo "Audit report: installed config vs repository"
echo "Repo: $REPO_ROOT"
echo "Home: $HOME_DIR"
echo

printf "%-15s %-10s %-60s %s\n" "STATUS" "KIND" "TARGET" "DETAIL"
printf "%-15s %-10s %-60s %s\n" "------" "----" "------" "------"
for row in "${RESULTS[@]}"; do
  IFS='|' read -r status kind source target detail <<< "$row"
  printf "%-15s %-10s %-60s %s\n" "$status" "$kind" "$target" "$detail"
done

echo
echo "Summary by status:"
for status in "${!STATUS_COUNT[@]}"; do
  echo "- $status: ${STATUS_COUNT[$status]}"
done
