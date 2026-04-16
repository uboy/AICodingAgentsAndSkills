#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
MANIFEST_PATH="$REPO_ROOT/deploy/manifest.txt"
HOME_DIR="${HOME:-$(cd ~ && pwd -P)}"
BACKUP_ROOT=""
BACKUP_NAME=""
DRY_RUN=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --repo-root <path>    Override repository root
  --backup-root <path>  Override backup root (default: ~/.ai-agent-config-backups)
  --backup-name <name>  Backup directory name (default: timestamp)
  --dry-run             Print actions without copying
  -h, --help            Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
      MANIFEST_PATH="$REPO_ROOT/deploy/manifest.txt"
      shift 2
      ;;
    --backup-root)
      BACKUP_ROOT="$2"
      shift 2
      ;;
    --backup-name)
      BACKUP_NAME="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
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

if [[ -z "$BACKUP_ROOT" ]]; then
  BACKUP_ROOT="$HOME_DIR/.ai-agent-config-backups"
fi
if [[ -z "$BACKUP_NAME" ]]; then
  BACKUP_NAME="$(date +%Y%m%d-%H%M%S)"
fi

BACKUP_DIR="$BACKUP_ROOT/$BACKUP_NAME"
BACKUP_FILES_DIR="$BACKUP_DIR/files"
INDEX_PATH="$BACKUP_DIR/index.tsv"

run_cmd() {
  local desc="$1"
  shift
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY] $desc :: $*"
  else
    "$@"
  fi
}

echo "[*] Repo root: $REPO_ROOT"
echo "[*] Home dir: $HOME_DIR"
echo "[*] Backup dir: $BACKUP_DIR"

run_cmd "Create backup directory: $BACKUP_FILES_DIR" mkdir -p "$BACKUP_FILES_DIR"

declare -A SEEN_TARGETS=()
declare -a INDEX_ROWS=()

add_row() {
  local status="$1"
  local target="$2"
  local source_path="$3"
  local backup_path="$4"
  local notes="$5"
  INDEX_ROWS+=("$status|$target|$source_path|$backup_path|$notes")
}

while IFS='|' read -r source_rel target_rel; do
  line="${source_rel}${target_rel}"
  if [[ -z "${line// }" ]]; then
    continue
  fi
  [[ "${source_rel#"${source_rel%%[![:space:]]*}"}" == \#* ]] && continue
  target_rel="$(echo "$target_rel" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -z "$target_rel" ]] && continue

  if [[ -n "${SEEN_TARGETS["$target_rel"]+x}" ]]; then
    continue
  fi
  SEEN_TARGETS["$target_rel"]=1

  target_path="$HOME_DIR/$target_rel"
  backup_path="$BACKUP_FILES_DIR/$target_rel"

  if [[ ! -e "$target_path" && ! -L "$target_path" ]]; then
    add_row "MISSING" "$target_rel" "$target_path" "" "Target does not exist in home."
    continue
  fi

  if [[ -L "$target_path" ]]; then
    linked="$(readlink "$target_path" || true)"
    if [[ -n "$linked" ]]; then
      if [[ "$linked" != /* ]]; then
        linked="$(cd "$(dirname "$target_path")" && cd "$(dirname "$linked")" && pwd -P)/$(basename "$linked")"
      fi
      repo_abs="$(cd "$REPO_ROOT" && pwd -P)"
      case "$linked" in
        "$repo_abs"/*)
          add_row "SKIP_LINKED_TO_REPO" "$target_rel" "$target_path" "" "Target is linked to repo source."
          continue
          ;;
      esac
    fi
  fi

  run_cmd "Create parent dir for backup: $(dirname "$backup_path")" mkdir -p "$(dirname "$backup_path")"
  run_cmd "Backup: $target_path -> $backup_path" cp -a "$target_path" "$backup_path"
  add_row "BACKED_UP" "$target_rel" "$target_path" "$backup_path" ""
done < "$MANIFEST_PATH"

if [[ $DRY_RUN -eq 0 ]]; then
  {
    echo -e "status\ttarget\tsource_path\tbackup_path\tnotes"
    for row in "${INDEX_ROWS[@]}"; do
      IFS='|' read -r status target source_path backup_path notes <<< "$row"
      echo -e "${status}\t${target}\t${source_path}\t${backup_path}\t${notes}"
    done
  } > "$INDEX_PATH"
fi

echo
echo "Backup summary:"
if [[ ${#INDEX_ROWS[@]} -eq 0 ]]; then
  echo "- no manifest targets processed"
else
  printf '%s\n' "${INDEX_ROWS[@]}" | cut -d'|' -f1 | sort | uniq -c | while read -r count status; do
    echo "- $status: $count"
  done
fi

echo
if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry-run finished. No files were copied."
else
  echo "Backup created at: $BACKUP_DIR"
  echo "Index file: $INDEX_PATH"
fi
