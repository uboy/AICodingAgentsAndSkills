#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
WORKTREES_ROOT=""
BASE_BRANCH=""
INCLUDE_CURSOR=0
INCLUDE_OPENCODE=0
DRY_RUN=0
AGENTS=("claude" "codex" "gemini")

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --repo-root <path>       Override repository root
  --worktrees-root <path>  Override worktrees directory
  --base-branch <name>     Base branch for new agent branches
  --agents <csv>           Agent list (default: claude,codex,gemini)
  --include-cursor         Add cursor agent
  --include-opencode       Add opencode agent
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

for dir in \
  "$REPO_ROOT/coordination" \
  "$REPO_ROOT/coordination/state" \
  "$REPO_ROOT/coordination/code_map" \
  "$REPO_ROOT/coordination/handoffs" \
  "$REPO_ROOT/coordination/reviews" \
  "$REPO_ROOT/coordination/locks" \
  "$WORKTREES_ROOT"; do
  if [[ ! -d "$dir" ]]; then
    run_cmd "Create directory: $dir" mkdir -p "$dir"
  fi
done

SESSION_USAGE_FILE="$REPO_ROOT/coordination/state/session-usage.json"
TASKS_FILE="$REPO_ROOT/coordination/tasks.jsonl"
if [[ ! -f "$TASKS_FILE" ]]; then
  run_cmd "Create local task tracker: $TASKS_FILE" touch "$TASKS_FILE"
fi
if [[ ! -f "$SESSION_USAGE_FILE" ]]; then
  seed_agent="codex"
  if [[ ${#AGENTS[@]} -gt 0 && -n "${AGENTS[0]}" ]]; then
    seed_agent="$(echo "${AGENTS[0]}" | tr '[:upper:]' '[:lower:]' | xargs)"
  fi
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  session_id="$(printf '%s-%s' "$(printf '%s' "$ts" | tr -d ':-')" "$seed_agent")"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY] Create session usage file: $SESSION_USAGE_FILE"
  else
    cat > "$SESSION_USAGE_FILE" <<EOF
{
  "_comment": "Per-session usage tracker. Updated by agents. See policy/subscription-limits-policy.md",
  "session_id": "$session_id",
  "agent": "$seed_agent",
  "session_start_utc": "$ts",
  "last_checkpoint_utc": "$ts",
  "estimated_tokens_used": 0,
  "estimated_usage_percent": 0,
  "gate_tokens_since_last_confirm": 0,
  "auto_resume_attempts": 0,
  "status": "idle",
  "resume_after_utc": null,
  "last_completed_step": "none",
  "next_step": "startup"
}
EOF
  fi
fi

echo "[*] Repo root: $REPO_ROOT"
echo "[*] Base branch: $BASE_BRANCH"
echo "[*] Worktrees root: $WORKTREES_ROOT"
echo "[*] Local task tracker: $TASKS_FILE"
echo "[*] Session usage file: $SESSION_USAGE_FILE"
if [[ $BASE_EXISTS -eq 0 ]]; then
  echo "[!] Base branch has no commits. Worktrees will not be created until initial commit exists." >&2
fi

for agent in "${AGENTS[@]}"; do
  agent="$(echo "$agent" | tr '[:upper:]' '[:lower:]' | xargs)"
  [[ -z "$agent" ]] && continue
  branch="agent/$agent"
  if [[ $BASE_EXISTS -eq 1 ]]; then
    worktree="$WORKTREES_ROOT/$agent"
  else
    worktree="$REPO_ROOT"
  fi
  state_file="$REPO_ROOT/coordination/state/$agent.md"

  echo "[*] Prepare agent: $agent"

  if [[ $BASE_EXISTS -eq 1 ]]; then
    if [[ -e "$worktree" && ! -e "$worktree/.git" ]]; then
      echo "[!] Path exists and is not a git worktree, skipping: $worktree" >&2
      continue
    fi

    if [[ ! -e "$worktree" ]]; then
      if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$branch"; then
        run_cmd "Create worktree from existing branch: $branch -> $worktree" \
          git -C "$REPO_ROOT" worktree add "$worktree" "$branch"
      else
        run_cmd "Create worktree and branch: $branch from $BASE_BRANCH -> $worktree" \
          git -C "$REPO_ROOT" worktree add -b "$branch" "$worktree" "$BASE_BRANCH"
      fi
    else
      echo "[=] Worktree exists: $worktree"
    fi
  fi

  if [[ ! -f "$state_file" ]]; then
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "[DRY] Create state file: $state_file"
    else
      cat > "$state_file" <<EOF
# Agent State

- agent: \`$agent\`
- branch: \`$(if [[ $BASE_EXISTS -eq 1 ]]; then echo "$branch"; else echo "uninitialized"; fi)\`
- task_id: \`none\`
- status: \`idle\`
- last_updated_utc: \`$ts\`
- workspace: \`$(if [[ $BASE_EXISTS -eq 1 ]]; then echo ".worktrees/$agent"; else echo "."; fi)\`
- notes:
  - initialized by scripts/run-multi-agent.sh
  - $(if [[ $BASE_EXISTS -eq 1 ]]; then echo "ready"; else echo "create initial commit to enable worktrees"; fi)
EOF
    fi
  fi
done

echo
echo "Launch hints:"
for agent in "${AGENTS[@]}"; do
  agent="$(echo "$agent" | tr '[:upper:]' '[:lower:]' | xargs)"
  [[ -z "$agent" ]] && continue
  if [[ $BASE_EXISTS -eq 1 ]]; then
    worktree="$WORKTREES_ROOT/$agent"
  else
    worktree="$REPO_ROOT"
  fi
  case "$agent" in
    claude) cli="claude" ;;
    codex) cli="codex" ;;
    gemini) cli="gemini" ;;
    cursor) cli="cursor" ;;
    opencode) cli="opencode" ;;
    *) cli="$agent" ;;
  esac
  echo "- $agent: cd \"$worktree\"; $cli"
done

echo
echo "Next: use scripts/sync-agents.sh to report/sync/integrate agent branches."
