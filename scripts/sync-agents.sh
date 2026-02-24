#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
WORKTREES_ROOT=""
BASE_BRANCH=""
INCLUDE_CURSOR=0
INCLUDE_OPENCODE=0
FETCH=0
REBASE=0
DRY_RUN=0
MODE="report"
AGENTS=("claude" "codex" "gemini")

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --repo-root <path>       Override repository root
  --worktrees-root <path>  Override worktrees directory
  --base-branch <name>     Base branch for compare/rebase/integrate
  --agents <csv>           Agent list (default: claude,codex,gemini)
  --include-cursor         Add cursor agent
  --include-opencode       Add opencode agent
  --mode <report|sync|integrate>
  --fetch                  git fetch --all --prune before sync
  --rebase                 In sync mode, rebase clean agent branches onto base
  --dry-run                Print actions without changes
  -h, --help               Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
      shift 2
      ;;
    --worktrees-root)
      WORKTREES_ROOT="$2"
      shift 2
      ;;
    --base-branch)
      BASE_BRANCH="$2"
      shift 2
      ;;
    --agents)
      IFS=',' read -r -a AGENTS <<< "$2"
      shift 2
      ;;
    --include-cursor)
      INCLUDE_CURSOR=1
      shift
      ;;
    --include-opencode)
      INCLUDE_OPENCODE=1
      shift
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --fetch)
      FETCH=1
      shift
      ;;
    --rebase)
      REBASE=1
      shift
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

if [[ ! "$MODE" =~ ^(report|sync|integrate)$ ]]; then
  echo "Invalid mode: $MODE" >&2
  exit 1
fi

run_cmd() {
  local desc="$1"
  shift
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY] $desc :: $*"
  else
    "$@"
  fi
}

if ! command -v git >/dev/null 2>&1; then
  echo "git is required." >&2
  exit 1
fi

if [[ ! -d "$REPO_ROOT" ]]; then
  echo "Repo root not found: $REPO_ROOT" >&2
  exit 1
fi

if [[ "$(git -C "$REPO_ROOT" rev-parse --is-inside-work-tree 2>/dev/null || true)" != "true" ]]; then
  echo "Not a git repository: $REPO_ROOT" >&2
  exit 1
fi

if [[ -z "$WORKTREES_ROOT" ]]; then
  WORKTREES_ROOT="$REPO_ROOT/.worktrees"
fi

if [[ -z "$BASE_BRANCH" ]]; then
  BASE_BRANCH="$(git -C "$REPO_ROOT" branch --show-current)"
  if [[ -z "$BASE_BRANCH" ]]; then
    BASE_BRANCH="$(git -C "$REPO_ROOT" symbolic-ref --short HEAD 2>/dev/null || true)"
    if [[ -z "$BASE_BRANCH" ]]; then
      BASE_BRANCH="main"
    fi
  fi
fi

BASE_EXISTS=1
if ! git -C "$REPO_ROOT" rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
  BASE_EXISTS=0
fi

if [[ $INCLUDE_CURSOR -eq 1 ]]; then
  has_cursor=0
  for agent in "${AGENTS[@]}"; do
    if [[ "$agent" == "cursor" ]]; then
      has_cursor=1
      break
    fi
  done
  if [[ $has_cursor -eq 0 ]]; then
    AGENTS+=("cursor")
  fi
fi

if [[ $INCLUDE_OPENCODE -eq 1 ]]; then
  has_opencode=0
  for agent in "${AGENTS[@]}"; do
    if [[ "$agent" == "opencode" ]]; then
      has_opencode=1
      break
    fi
  done
  if [[ $has_opencode -eq 0 ]]; then
    AGENTS+=("opencode")
  fi
fi

if [[ $FETCH -eq 1 ]]; then
  run_cmd "Fetch all remotes" git -C "$REPO_ROOT" fetch --all --prune
fi

declare -a ROWS=()

for agent in "${AGENTS[@]}"; do
  agent="$(echo "$agent" | tr '[:upper:]' '[:lower:]' | xargs)"
  [[ -z "$agent" ]] && continue
  branch="agent/$agent"
  worktree="$WORKTREES_ROOT/$agent"
  ahead=""
  behind=""
  dirty="false"
  notes=()

  if ! git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$branch"; then
    notes+=("branch missing")
  fi

  if [[ ! -d "$worktree" ]]; then
    notes+=("worktree missing")
  else
    if [[ -n "$(git -C "$worktree" status --porcelain 2>/dev/null || true)" ]]; then
      dirty="true"
      notes+=("dirty")
    fi
  fi

  if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$branch"; then
    if [[ $BASE_EXISTS -eq 1 ]]; then
      counts="$(git -C "$REPO_ROOT" rev-list --left-right --count "$BASE_BRANCH...$branch" 2>/dev/null || true)"
      if [[ -n "$counts" ]]; then
        behind="$(echo "$counts" | awk '{print $1}')"
        ahead="$(echo "$counts" | awk '{print $2}')"
      fi
    else
      notes+=("base branch has no commits")
    fi
  fi

  if [[ "$MODE" == "sync" && $REBASE -eq 1 && "$dirty" == "false" && -d "$worktree" ]] && git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$branch"; then
    if [[ $BASE_EXISTS -eq 1 ]]; then
      run_cmd "Rebase $branch onto $BASE_BRANCH" git -C "$worktree" rebase "$BASE_BRANCH"
      notes+=("rebased")
    else
      notes+=("skip rebase: base branch has no commits")
    fi
  fi

  notes_text="none"
  if [[ ${#notes[@]} -gt 0 ]]; then
    notes_text="$(IFS=', '; echo "${notes[*]}")"
  fi
  ROWS+=("$agent|$branch|$ahead|$behind|$dirty|$notes_text")
done

if [[ "$MODE" == "integrate" ]]; then
  if [[ $BASE_EXISTS -eq 0 ]]; then
    echo "Integration requires a base branch with at least one commit: $BASE_BRANCH" >&2
    exit 1
  fi

  if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "Integration requires a clean repo root working tree." >&2
    exit 1
  fi

  run_cmd "Checkout base branch: $BASE_BRANCH" git -C "$REPO_ROOT" checkout "$BASE_BRANCH"

  for row in "${ROWS[@]}"; do
    IFS='|' read -r agent branch ahead behind dirty notes <<< "$row"
    [[ -z "$ahead" || "$ahead" == "0" ]] && continue
    if [[ "$dirty" == "true" ]]; then
      echo "[!] Skip dirty branch: $branch" >&2
      continue
    fi
    run_cmd "Merge $branch into $BASE_BRANCH" git -C "$REPO_ROOT" merge --no-ff "$branch"
  done
fi

echo
echo "Agent sync report"
echo "Mode: $MODE"
echo "Base branch: $BASE_BRANCH"
echo "Worktrees root: $WORKTREES_ROOT"
echo
printf "%-10s %-18s %-8s %-8s %-8s %s\n" "AGENT" "BRANCH" "AHEAD" "BEHIND" "DIRTY" "NOTES"
printf "%-10s %-18s %-8s %-8s %-8s %s\n" "-----" "------" "-----" "------" "-----" "-----"
for row in "${ROWS[@]}"; do
  IFS='|' read -r agent branch ahead behind dirty notes <<< "$row"
  printf "%-10s %-18s %-8s %-8s %-8s %s\n" "$agent" "$branch" "${ahead:-}" "${behind:-}" "$dirty" "$notes"
done
