#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
MANIFEST_PATH="$REPO_ROOT/deploy/manifest.txt"
HOME_DIR="${HOME:-$(cd ~ && pwd -P)}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
NO_DEPS=0
NON_INTERACTIVE=0
CONFLICT_ACTION="ask"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --repo-root <path>          Override repository root
  --conflict-action <mode>    ask|replace|merge|keep (default: ask)
  --dry-run                   Print actions without changing files
  --no-deps                   Do not auto-install dependencies
  --non-interactive           Never prompt; with ask-mode defaults to keep
  -h, --help                  Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
      MANIFEST_PATH="$REPO_ROOT/deploy/manifest.txt"
      shift 2
      ;;
    --conflict-action)
      CONFLICT_ACTION="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --no-deps)
      NO_DEPS=1
      shift
      ;;
    --non-interactive)
      NON_INTERACTIVE=1
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

if [[ ! "$CONFLICT_ACTION" =~ ^(ask|replace|merge|keep)$ ]]; then
  echo "Invalid --conflict-action: $CONFLICT_ACTION" >&2
  exit 1
fi

log_step() { echo "[*] $*"; }
log_warn() { echo "[!] $*" >&2; }

run_cmd() {
  local desc="$1"
  shift
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY] $desc :: $*"
  else
    "$@"
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

abspath() {
  local p="$1"
  local dir
  dir="$(cd "$(dirname "$p")" && pwd -P)"
  echo "$dir/$(basename "$p")"
}

ensure_parent_dir() {
  local target="$1"
  local parent
  parent="$(dirname "$target")"
  run_cmd "Create directory: $parent" mkdir -p "$parent"
}

backup_existing() {
  local target="$1"
  local backup="${target}.backup-${TIMESTAMP}"
  run_cmd "Backup: $target -> $backup" cp -a "$target" "$backup"
}

show_diff() {
  local source="$1"
  local target="$2"
  echo
  echo "--- DIFF: $target <-> $source"
  if command_exists git; then
    git --no-pager diff --no-index -- "$target" "$source" || true
  elif command_exists diff; then
    diff -u "$target" "$source" || true
  else
    echo "(diff tool not found)"
  fi
}

write_merged_conflict_file() {
  local source="$1"
  local target="$2"
  local existing_text=""
  if [[ -f "$target" ]]; then
    existing_text="$(cat "$target")"
  fi
  local source_text
  source_text="$(cat "$source")"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY] Write merged conflict file: $target"
    return
  fi
  cat > "$target" <<EOF
<<<<<<< LOCAL ($target)
$existing_text
=======
$source_text
>>>>>>> REPOSITORY ($source)
EOF
}

resolve_link_target() {
  local target="$1"
  local link
  link="$(readlink "$target")"
  if [[ "$link" = /* ]]; then
    echo "$link"
  else
    abspath "$(dirname "$target")/$link"
  fi
}

is_same_symlink() {
  local source="$1"
  local target="$2"
  if [[ ! -L "$target" ]]; then
    return 1
  fi
  local src_abs
  src_abs="$(abspath "$source")"
  local link_abs
  link_abs="$(resolve_link_target "$target")"
  [[ "$src_abs" == "$link_abs" ]]
}

create_link() {
  local source="$1"
  local target="$2"
  local src_abs
  src_abs="$(abspath "$source")"
  ensure_parent_dir "$target"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY] Link: $target -> $src_abs"
    return
  fi
  rm -rf "$target"
  ln -s "$src_abs" "$target"
}

select_action() {
  local source="$1"
  local target="$2"
  if [[ "$CONFLICT_ACTION" != "ask" ]]; then
    echo "$CONFLICT_ACTION"
    return
  fi
  if [[ $NON_INTERACTIVE -eq 1 ]]; then
    echo "keep"
    return
  fi

  show_diff "$source" "$target"
  echo
  echo "Target exists: $target"
  echo "[R]eplace with link to repo"
  echo "[M]erge into local file (conflict markers, no link)"
  echo "[K]eep local file (no link)"
  while true; do
    read -r -p "Choose action [R/M/K]: " answer
    answer="$(echo "$answer" | tr '[:upper:]' '[:lower:]')"
    case "$answer" in
      r) echo "replace"; return ;;
      m) echo "merge"; return ;;
      k) echo "keep"; return ;;
      *) log_warn "Invalid choice. Enter R, M, or K." ;;
    esac
  done
}

deploy_file() {
  local source="$1"
  local target="$2"
  if [[ ! -f "$source" ]]; then
    log_warn "Skip missing source file: $source"
    return
  fi

  if [[ ! -e "$target" && ! -L "$target" ]]; then
    create_link "$source" "$target"
    return
  fi

  if is_same_symlink "$source" "$target"; then
    echo "[=] Already linked: $target"
    return
  fi

  local action
  action="$(select_action "$source" "$target")"
  case "$action" in
    replace)
      backup_existing "$target"
      create_link "$source" "$target"
      ;;
    merge)
      backup_existing "$target"
      write_merged_conflict_file "$source" "$target"
      ;;
    keep)
      echo "[=] Keep local: $target"
      ;;
    *)
      log_warn "Unsupported action: $action"
      ;;
  esac
}

deploy_entry() {
  local source_rel="$1"
  local target_rel="$2"
  local source_path="$REPO_ROOT/$source_rel"
  local target_path="$HOME_DIR/$target_rel"

  if [[ ! -e "$source_path" ]]; then
    log_warn "Skip (source missing): $source_rel"
    return
  fi

  if [[ -d "$source_path" ]]; then
    log_step "Deploy directory: $source_rel -> $target_rel"
    while IFS= read -r src_file; do
      local rel="${src_file#"$source_path"/}"
      deploy_file "$src_file" "$target_path/$rel"
    done < <(find "$source_path" -type f)
  else
    log_step "Deploy file: $source_rel -> $target_rel"
    deploy_file "$source_path" "$target_path"
  fi
}

ensure_dependency() {
  local cmd="$1"
  local package_name="$2"
  if command_exists "$cmd"; then
    return 0
  fi
  if [[ $NO_DEPS -eq 1 ]]; then
    log_warn "$cmd not found. Re-run without --no-deps to auto-install."
    return 1
  fi

  if command_exists brew; then
    run_cmd "Install dependency: brew install $package_name" brew install "$package_name"
  elif command_exists apt-get; then
    run_cmd "Install dependency: apt-get install $package_name" sudo apt-get update
    run_cmd "Install dependency: apt-get install $package_name" sudo apt-get install -y "$package_name"
  elif command_exists dnf; then
    run_cmd "Install dependency: dnf install $package_name" sudo dnf install -y "$package_name"
  elif command_exists yum; then
    run_cmd "Install dependency: yum install $package_name" sudo yum install -y "$package_name"
  elif command_exists pacman; then
    run_cmd "Install dependency: pacman -S $package_name" sudo pacman -Sy --noconfirm "$package_name"
  elif command_exists zypper; then
    run_cmd "Install dependency: zypper install $package_name" sudo zypper install -y "$package_name"
  else
    log_warn "$cmd missing and no supported package manager detected."
    return 1
  fi
  command_exists "$cmd"
}

ensure_git_config() {
  if ! command_exists git; then
    return
  fi

  local name email
  name="$(git config --global --get user.name || true)"
  email="$(git config --global --get user.email || true)"

  if [[ -z "$name" ]]; then
    if [[ $NON_INTERACTIVE -eq 1 ]]; then
      log_warn "git user.name not configured. Set it manually."
    else
      read -r -p "git user.name is empty. Enter your name (or empty to skip): " name_input
      if [[ -n "${name_input:-}" ]]; then
        run_cmd "Set git user.name" git config --global user.name "$name_input"
      fi
    fi
  fi

  if [[ -z "$email" ]]; then
    if [[ $NON_INTERACTIVE -eq 1 ]]; then
      log_warn "git user.email not configured. Set it manually."
    else
      read -r -p "git user.email is empty. Enter your email (or empty to skip): " email_input
      if [[ -n "${email_input:-}" ]]; then
        run_cmd "Set git user.email" git config --global user.email "$email_input"
      fi
    fi
  fi

  run_cmd "Set git core.excludesfile" git config --global core.excludesfile "$HOME_DIR/.gitignore_global"
  run_cmd "Set git core.hooksPath" git config --global core.hooksPath "$HOME_DIR/.githooks"
}

invoke_auto_backup() {
  local backup_script="$SCRIPT_DIR/backup-user-config.sh"
  if [[ ! -f "$backup_script" ]]; then
    echo "Backup script not found: $backup_script" >&2
    exit 1
  fi

  log_step "Creating automatic pre-install backup"
  local cmd=(bash "$backup_script" --repo-root "$REPO_ROOT" --backup-name "install-$TIMESTAMP")
  if [[ $DRY_RUN -eq 1 ]]; then
    cmd+=(--dry-run)
  fi
  "${cmd[@]}"
}

if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "Manifest not found: $MANIFEST_PATH" >&2
  exit 1
fi

log_step "Repo root: $REPO_ROOT"
invoke_auto_backup
log_step "Checking dependencies"
ensure_dependency git git || true
ensure_dependency gitleaks gitleaks || true

entry_count=0
while IFS='|' read -r source_rel target_rel; do
  line="${source_rel}${target_rel}"
  if [[ -z "${line// }" ]]; then
    continue
  fi
  [[ "${source_rel#"${source_rel%%[![:space:]]*}"}" == \#* ]] && continue
  source_rel="$(echo "$source_rel" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  target_rel="$(echo "$target_rel" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -z "$source_rel" || -z "$target_rel" ]] && continue
  entry_count=$((entry_count + 1))
  deploy_entry "$source_rel" "$target_rel"
done < "$MANIFEST_PATH"

log_step "Manifest entries: $entry_count"
ensure_git_config

if [[ -f "$HOME_DIR/.githooks/pre-commit" && $DRY_RUN -eq 0 ]]; then
  chmod +x "$HOME_DIR/.githooks/pre-commit" || true
fi

log_step "Done."
