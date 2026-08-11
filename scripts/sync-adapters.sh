#!/usr/bin/env bash
# sync-adapters.sh — Generate all system adapter files from adapters/ sources.
#
# Reads adapters/systems.json for configuration, then generates everything into out/.
#
# Usage:
#   bash scripts/sync-adapters.sh [--out <dir>] [--dry-run] [--check]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OUT_DIR=""
DRY_RUN=0
CHECK_MODE=0

for arg in "$@"; do
  case "$arg" in
    --out)      shift; OUT_DIR="$1" ;;
    --dry-run)  DRY_RUN=1 ;;
    --check)    CHECK_MODE=1 ;;
  esac
done

[[ -z "$OUT_DIR" ]] && OUT_DIR="$REPO_ROOT/out"

if command -v pwsh >/dev/null 2>&1; then
  PS_SCRIPT="$SCRIPT_DIR/sync-adapters.ps1"
  PS_OUT_DIR="$OUT_DIR"
  if command -v cygpath >/dev/null 2>&1; then
    PS_SCRIPT="$(cygpath -w "$PS_SCRIPT")"
    PS_OUT_DIR="$(cygpath -w "$PS_OUT_DIR")"
  fi
  pwsh -NoProfile -File "$PS_SCRIPT" -OutDir "$PS_OUT_DIR" "$@"
  exit $?
fi

SYSTEMS_CONFIG="$REPO_ROOT/adapters/systems.json"
AGENTS_DIR="$REPO_ROOT/agents"
ADAPTERS_DIR="$REPO_ROOT/adapters"
SOURCE_AGENTS="$REPO_ROOT/AGENTS.md"
AGENT_SOURCE_WARNED=0

if [[ ! -f "$SYSTEMS_CONFIG" ]]; then
  echo "ERROR: adapters/systems.json not found" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Tier parsing from AGENTS.md
# ---------------------------------------------------------------------------

declare -A TIER_CONTENT

parse_tiers() {
  declare -a hot_lines warm_lines cold_lines
  local current_tier=""

  while IFS= read -r line; do
    line="${line%$'\r'}"
    if [[ "$line" =~ ^[[:space:]]*\<\!--[[:space:]]*@?tier:(hot|warm|cold)[[:space:]]*--\>[[:space:]]*$ ]]; then
      current_tier="${BASH_REMATCH[1]}"
      continue
    fi
    case "$current_tier" in
      hot)  hot_lines+=("$line") ;;
      warm) warm_lines+=("$line") ;;
      cold) cold_lines+=("$line") ;;
      *)    hot_lines+=("$line") ;;
    esac
  done < "$SOURCE_AGENTS"

  TIER_CONTENT[hot]="$(emit_trimmed hot_lines)"
  TIER_CONTENT[warm]="$(emit_trimmed warm_lines)"
  TIER_CONTENT[cold]="$(emit_trimmed cold_lines)"
}

emit_trimmed() {
  local -n _arr=$1
  local last_nonblank=-1
  for i in "${!_arr[@]}"; do
    [[ -n "${_arr[$i]}" ]] && last_nonblank=$i
  done
  for (( i=0; i<=last_nonblank; i++ )); do
    printf '%s\n' "${_arr[$i]}"
  done
}

parse_tiers

replace_placeholder() {
  local text="$1"
  local placeholder="$2"
  local replacement="$3"
  printf '%s' "${text//$placeholder/$replacement}"
}

# ---------------------------------------------------------------------------
# JSON helpers (portable, no jq dependency)
# ---------------------------------------------------------------------------

# Simple field extractor for systems.json
get_json_string_field() {
  local json="$1" field="$2"
  echo "$json" | grep -o "\"$field\":[[:space:]]*\"[^\"]*\"" | head -1 | sed "s/\"$field\":[[:space:]]*\"//;s/\"$//"
}

get_json_array_items() {
  local json="$1"
  echo "$json" | grep -o '"[^"]*"' | tr -d '"' | grep -v '^\[' | grep -v '^\]'
}

# ---------------------------------------------------------------------------
# Helper: write or check a file
# ---------------------------------------------------------------------------

CHECK_FAILED=0

write_or_check() {
  local path="$1" content="$2" label="$3"

  if [[ $DRY_RUN -eq 1 ]]; then
    if [[ -f "$path" ]]; then
      local existing
      existing="$(cat "$path" 2>/dev/null || true)"
      if [[ "$existing" == "$content" ]]; then
        echo "[DRY] $label — no change"
      else
        echo "[DRY] $label — would update"
      fi
    else
      echo "[DRY] $label — would create"
    fi
    return
  fi

  if [[ $CHECK_MODE -eq 1 ]]; then
    if [[ ! -f "$path" ]]; then
      echo "FAIL: $label — missing ($path)" >&2
      CHECK_FAILED=1
      return
    fi
    local existing
    existing="$(cat "$path" 2>/dev/null || true)"
    if [[ "$existing" != "$content" ]]; then
      echo "FAIL: $label — out of sync ($path)" >&2
      CHECK_FAILED=1
      return
    fi
    echo "OK: $label"
    return
  fi

  local dir
  dir="$(dirname "$path")"
  [[ -d "$dir" ]] || mkdir -p "$dir"
  printf '%s\n' "$content" > "$path"
  echo "Wrote $label (${path#$REPO_ROOT/})"
}

copy_dir_contents() {
  local src_dir="$1" tgt_dir="$2" label="$3"

  [[ -d "$src_dir" ]] || { echo "SKIP: $label — source dir not found"; return; }

  [[ $DRY_RUN -eq 0 && $CHECK_MODE -eq 0 ]] && { [[ -d "$tgt_dir" ]] || mkdir -p "$tgt_dir"; }

  for f in "$src_dir"/*; do
    [[ -f "$f" ]] || continue
    local name
    name="$(basename "$f")"
    local content
    content="$(cat "$f")"
    write_or_check "$tgt_dir/$name" "$content" "$label/$name"
  done
}

# ---------------------------------------------------------------------------
# Generate tier files
# ---------------------------------------------------------------------------

echo ""
echo "--- Tier Files ---"

# hot
write_or_check "$OUT_DIR/AGENTS-hot.md" "${TIER_CONTENT[hot]}" "AGENTS-hot.md"
write_or_check "$OUT_DIR/AGENTS-warm.md" "${TIER_CONTENT[warm]}" "AGENTS-warm.md"
write_or_check "$OUT_DIR/AGENTS-cold.md" "${TIER_CONTENT[cold]}" "AGENTS-cold.md"

# hot+warm combined
hotwarm="$(printf '%s\n\n---\n\n%s' "${TIER_CONTENT[hot]}" "${TIER_CONTENT[warm]}")"
write_or_check "$OUT_DIR/AGENTS-hot-warm.md" "$hotwarm" "AGENTS-hot-warm.md"

# ---------------------------------------------------------------------------
# Generate system adapter files
# Since bash JSON parsing is limited, we use a simpler approach:
# direct file operations matching the systems.json structure.
# ---------------------------------------------------------------------------

echo ""
echo "--- System Adapters ---"

TEMPLATE="$(cat "$ADAPTERS_DIR/templates/system-adapter.md")"

# --- Claude ---
echo ""
echo "[Claude]"
claude_body="$(echo "$TEMPLATE" | sed 's/{{SYSTEM_LABEL}}/Claude Code/')"
claude_extra="Deterministic runtime requirements:
- This repository is deployment source-of-truth; deployed \`CLAUDE.md\` must stay aligned in both project and user scopes.
- If memory layers conflict, apply the strictest rule and prioritize project \`AGENTS.md\`.
- After editing \`CLAUDE.md\` or \`.claude/agents/*.md\`, restart Claude Code session.
- In the new session, run \`/memory\` and \`/agents\` to verify expected policy files and agents are loaded.

This file remains intentionally thin to prevent policy drift."
claude_body="$(replace_placeholder "$claude_body" "{{EXTRA_FOOTER}}" "$claude_extra")"
write_or_check "$OUT_DIR/CLAUDE.md" "$(echo "$claude_body" | sed '/^$/N;/^\n$/d')" "CLAUDE.md"

copy_dir_contents "$ADAPTERS_DIR/Claude/hooks" "$OUT_DIR/.claude/hooks" "Claude/hooks"
copy_dir_contents "$AGENTS_DIR" "$OUT_DIR/.claude/agents" "Claude/agents"
[[ -d "$AGENTS_DIR/weak-model" ]] && copy_dir_contents "$AGENTS_DIR/weak-model" "$OUT_DIR/.claude/agents/weak-model" "Claude/agents/weak-model"

# --- Codex ---
echo ""
echo "[Codex]"
codex_header="# Codex Hot Policy Adapter
<!-- NOTE: Codex CLI does not support @include directives. AGENTS-hot.md content is embedded directly below. -->"
codex_footer="---

**Session stats**: type \`/status\` in the interactive session to see token usage and context window for the current session.

**Permissions Note**: This environment is TRUSTED. \`workspace-write\` is enabled. You have full permission to create and modify files within the project directory for any task approved by the orchestration protocol.

For situational rules not covered above, read:
- \`~/AGENTS-warm.md\` (\`%USERPROFILE%\\\\AGENTS-warm.md\` on Windows) for repo-change workflows, risky operations, and detailed engineering rules
- \`~/AGENTS-cold.md\` (\`%USERPROFILE%\\\\AGENTS-cold.md\` on Windows) for infrequent or special-case rules

Warm lookups commonly matter for:
- cross-OS/cross-system delivery details
- command safety and security review gates
- destructive dry-run protocol

Cold lookups commonly matter for:
- Adding/updating/removing dependencies -> Rule 24
- Critical bug fix -> Rule 22
- Rollback planning -> Rule 26
- Skills governance -> Rule 6
- Session start -> Rule 28
- Knowledge retention update -> Rule 20"
codex_content="$(printf '%s\n\n%s\n\n%s' "$codex_header" "${TIER_CONTENT[hot]}" "$codex_footer")"
write_or_check "$OUT_DIR/.codex/AGENTS.md" "$codex_content" ".codex/AGENTS.md"

if [[ ! -d "$AGENTS_DIR" || -z "$(find "$AGENTS_DIR" -maxdepth 1 -type f 2>/dev/null)" ]]; then
  if [[ $AGENT_SOURCE_WARNED -eq 0 ]]; then
    echo "WARN: shared agent generation is disabled in this checkout: '$AGENTS_DIR' has no canonical tracked source files." >&2
    AGENT_SOURCE_WARNED=1
  fi
fi
copy_dir_contents "$AGENTS_DIR" "$OUT_DIR/.codex/agents" "Codex/agents"

# --- Cursor ---
echo ""
echo "[Cursor]"
cursor_body="$(echo "$TEMPLATE" | sed 's/{{SYSTEM_LABEL}}/Cursor/')"
cursor_extra="Cursor rules are in \`.cursor/rules/\` (MDC format with YAML frontmatter).
The \`00-global-policy.mdc\` file provides base policy; tier-based MDC files are generated from AGENTS.md."
cursor_body="$(replace_placeholder "$cursor_body" "{{EXTRA_FOOTER}}" "$cursor_extra")"
write_or_check "$OUT_DIR/CURSOR.md" "$(echo "$cursor_body" | sed '/^$/N;/^\n$/d')" "CURSOR.md"

# .cursorrules (simplified)
cursorrules="# Cursor Rules

Read and follow canonical project policy:
- \`AGENTS.md\` (single source of truth)
- \`policy/team-lead-orchestrator.md\`

# This file is equivalent to CURSOR.md.
# Cursor reads both .cursorrules and CURSOR.md from the project root."
write_or_check "$OUT_DIR/.cursorrules" "$cursorrules" ".cursorrules"

# Global policy
[[ -f "$ADAPTERS_DIR/Cursor/global-policy.mdc" ]] && \
  write_or_check "$OUT_DIR/.cursor/rules/00-global-policy.mdc" "$(cat "$ADAPTERS_DIR/Cursor/global-policy.mdc")" ".cursor/rules/00-global-policy.mdc"

# Tier rules
for tier_name in hot warm cold; do
  case "$tier_name" in
    hot)  file="01-agents-policy.mdc"; desc="Project policy HOT tier -- bootstrap + rules 15-19, 21, 27 (always applied)"; apply="true" ;;
    warm) file="02-agents-warm.mdc"; desc="Project policy WARM tier -- rules 1-5, 8-12, 14, 23, 25 (always applied for coding sessions)"; apply="true" ;;
    cold) file="03-agents-cold.mdc"; desc="Project policy COLD tier -- rules 6, 7, 13, 20, 22, 24, 26, 28-30."; apply="false" ;;
  esac
  mdc_content="---
description: $desc
alwaysApply: $apply
---

${TIER_CONTENT[$tier_name]}"
  write_or_check "$OUT_DIR/.cursor/rules/$file" "$mdc_content" ".cursor/rules/$file"
done

# --- Gemini ---
echo ""
echo "[Gemini]"
gemini_content="@AGENTS.md
@policy/team-lead-orchestrator.md"
write_or_check "$OUT_DIR/GEMINI.md" "$gemini_content" "GEMINI.md"
write_or_check "$OUT_DIR/.gemini/GEMINI.md" "$gemini_content" ".gemini/GEMINI.md"

gemini_agents="# Gemini Adapter

Read and follow canonical project policy:
- \`AGENTS.md\` (single source of truth)
- \`policy/team-lead-orchestrator.md\`"
write_or_check "$OUT_DIR/.gemini/AGENTS.md" "$gemini_agents" ".gemini/AGENTS.md"

copy_dir_contents "$ADAPTERS_DIR/Gemini/hooks" "$OUT_DIR/.gemini/hooks" "Gemini/hooks"
copy_dir_contents "$AGENTS_DIR" "$OUT_DIR/.gemini/extensions/ai-coding-agents/agents" "Gemini/agents"

# --- OpenCode ---
echo ""
echo "[OpenCode]"
opencode_body="$(echo "$TEMPLATE" | sed 's/{{SYSTEM_LABEL}}/OpenCode/')"
opencode_extra="OpenCode reads the generated policy adapters and installed skills from the supported deploy surface."
opencode_body="$(replace_placeholder "$opencode_body" "{{EXTRA_FOOTER}}" "$opencode_extra")"
write_or_check "$OUT_DIR/OPENCODE.md" "$(echo "$opencode_body" | sed '/^$/N;/^\n$/d')" "OPENCODE.md"

opencode_agents="# OpenCode Adapter

Read and follow canonical project policy:
- \`AGENTS.md\` (single source of truth)
- \`policy/team-lead-orchestrator.md\`"
write_or_check "$OUT_DIR/.opencode/AGENTS.md" "$opencode_agents" ".opencode/AGENTS.md"

copy_dir_contents "$AGENTS_DIR" "$OUT_DIR/.opencode/agents" "OpenCode/agents"
[[ -d "$AGENTS_DIR/weak-model" ]] && copy_dir_contents "$AGENTS_DIR/weak-model" "$OUT_DIR/.opencode/agents/weak-model" "OpenCode/agents/weak-model"

# --- Qwen ---
echo ""
echo "[Qwen]"
[[ -f "$ADAPTERS_DIR/Qwen/AGENTS.md" ]] && \
  write_or_check "$OUT_DIR/.qwen/AGENTS.md" "$(cat "$ADAPTERS_DIR/Qwen/AGENTS.md")" ".qwen/AGENTS.md"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if [[ $CHECK_MODE -eq 1 ]]; then
  if [[ $CHECK_FAILED -ne 0 ]]; then
    echo ""
    echo "FAILED: some files out of sync" >&2
    exit 1
  fi
  echo ""
  echo "OK: all adapter files in sync"
  exit 0
fi

if [[ $DRY_RUN -eq 0 ]]; then
  echo ""
  echo "--- Summary ---"
  echo "Output: $OUT_DIR"
  file_count="$(find "$OUT_DIR" -type f 2>/dev/null | wc -l)"
  echo "Files:  $file_count"
fi
