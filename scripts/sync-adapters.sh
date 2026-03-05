#!/usr/bin/env bash
# sync-adapters.sh — Regenerate system-specific adapter files from tier sources.
#
# Adapters kept in sync:
#   .codex/AGENTS.md              ← AGENTS-hot.md (sandwiched by header/footer)
#   .cursor/rules/01-agents-policy.mdc  ← frontmatter + AGENTS-hot.md body
#   .cursor/rules/02-agents-warm.mdc    ← frontmatter + AGENTS-warm.md body
#   .cursor/rules/03-agents-cold.mdc    ← frontmatter + AGENTS-cold.md body
#
# Usage:
#   bash scripts/sync-adapters.sh            # write files and report
#   bash scripts/sync-adapters.sh --dry-run  # print what would change, do not write
#   bash scripts/sync-adapters.sh --check    # exit 1 if any file is out of sync

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DRY_RUN=0
CHECK_MODE=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --check)   CHECK_MODE=1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Source tier files
# ---------------------------------------------------------------------------

HOT_FILE="$REPO_ROOT/AGENTS-hot.md"
WARM_FILE="$REPO_ROOT/AGENTS-warm.md"
COLD_FILE="$REPO_ROOT/AGENTS-cold.md"

for f in "$HOT_FILE" "$WARM_FILE" "$COLD_FILE"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: source tier file not found: $f" >&2
    echo "       Run 'bash scripts/extract-agents-tier.sh' first." >&2
    exit 1
  fi
done

# Strip UTF-8 BOM (EF BB BF) if present — tier files may be BOM-encoded on Windows
strip_bom() { sed 's/^\xef\xbb\xbf//' "$1"; }

hot_content="$(strip_bom "$HOT_FILE")"
warm_content="$(strip_bom "$WARM_FILE")"
cold_content="$(strip_bom "$COLD_FILE")"

# ---------------------------------------------------------------------------
# Build target file contents
# ---------------------------------------------------------------------------

# --- .codex/AGENTS.md ---
# Structure: header (2 lines) + blank + AGENTS-hot body + blank + footer
CODEX_HEADER='# Codex Hot Policy Adapter
<!-- NOTE: Codex CLI does not support @include directives. AGENTS-hot.md content is embedded directly below. Keep in sync with AGENTS-hot.md. -->'

CODEX_FOOTER='---

**Session stats**: type `/status` in the interactive session to see token usage and context window for the current session.

**Permissions Note**: This environment is TRUSTED. `workspace-write` is enabled. You have full permission to create and modify files within the project directory for any task approved by the orchestration protocol.

For situational rules not covered above, read `~/AGENTS-cold.md` (`%USERPROFILE%\AGENTS-cold.md` on Windows) via tool call when the task requires it:
- Adding/updating/removing dependencies -> Rule 24
- Critical bug fix -> Rule 22
- Rollback planning -> Rule 26
- Skills governance -> Rule 6
- Session start -> Rule 28
- Knowledge retention update -> Rule 20'

codex_content="${CODEX_HEADER}

${hot_content}

${CODEX_FOOTER}"

# --- .cursor/rules/01-agents-policy.mdc ---
CURSOR_HOT_FM='---
description: Project policy HOT tier -- bootstrap + rules 15-19, 21, 27 (always applied)
alwaysApply: true
---'

cursor_hot_content="${CURSOR_HOT_FM}

${hot_content}"

# --- .cursor/rules/02-agents-warm.mdc ---
CURSOR_WARM_FM='---
description: Project policy WARM tier -- rules 1-5, 8-12, 14, 23, 25 (always applied for coding sessions)
alwaysApply: true
---'

cursor_warm_content="${CURSOR_WARM_FM}

${warm_content}"

# --- .cursor/rules/03-agents-cold.mdc ---
CURSOR_COLD_FM='---
description: Project policy COLD tier -- rules 6, 7, 13, 20, 22, 24, 26, 28-30. Load when: adding skills, changing permissions, adding dependencies, fixing critical bugs, planning rollbacks, starting a session, or updating agent memory.
alwaysApply: false
---'

cursor_cold_content="${CURSOR_COLD_FM}

${cold_content}"

# ---------------------------------------------------------------------------
# Helper: compare or write one adapter file
# ---------------------------------------------------------------------------

check_failed=0

sync_file() {
  local path="$1"
  local content="$2"
  local label="$3"

  if [[ $DRY_RUN -eq 1 ]]; then
    if [[ -f "$path" ]]; then
      existing="$(cat "$path")"
      if [[ "$existing" == "$content" ]]; then
        echo "[DRY] $label — no change"
      else
        echo "[DRY] $label — would update $path"
      fi
    else
      echo "[DRY] $label — would create $path"
    fi
    return 0
  fi

  if [[ $CHECK_MODE -eq 1 ]]; then
    if [[ ! -f "$path" ]]; then
      echo "FAIL: $path missing (run sync-adapters.sh to regenerate)" >&2
      check_failed=1
      return 0
    fi
    existing="$(cat "$path")"
    if [[ "$existing" != "$content" ]]; then
      echo "FAIL: $path is out of sync with tier sources (run sync-adapters.sh to regenerate)" >&2
      check_failed=1
    else
      echo "OK:   $path"
    fi
    return 0
  fi

  # Normal write mode
  if [[ -f "$path" ]]; then
    existing="$(cat "$path")"
    if [[ "$existing" == "$content" ]]; then
      echo "No change $path"
      return 0
    fi
  fi
  printf '%s\n' "$content" > "$path"
  echo "Wrote $path"
}

# ---------------------------------------------------------------------------
# Sync all adapters
# ---------------------------------------------------------------------------

sync_file "$REPO_ROOT/.codex/AGENTS.md"               "$codex_content"       "codex/AGENTS.md"
sync_file "$REPO_ROOT/.cursor/rules/01-agents-policy.mdc" "$cursor_hot_content"  "cursor/01-agents-policy.mdc"
sync_file "$REPO_ROOT/.cursor/rules/02-agents-warm.mdc"   "$cursor_warm_content" "cursor/02-agents-warm.mdc"
sync_file "$REPO_ROOT/.cursor/rules/03-agents-cold.mdc"   "$cursor_cold_content" "cursor/03-agents-cold.mdc"

# ---------------------------------------------------------------------------
# Final exit
# ---------------------------------------------------------------------------

if [[ $CHECK_MODE -eq 1 ]]; then
  if [[ $check_failed -ne 0 ]]; then
    exit 1
  fi
  echo "OK: all adapter files are in sync"
fi
