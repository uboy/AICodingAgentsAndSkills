#!/usr/bin/env bash
# extract-agents-tier.sh — Generate tier files from AGENTS.md
# Usage: bash scripts/extract-agents-tier.sh [--dry-run] [--check]
#
# Reads AGENTS.md, splits sections by <!-- @tier:X --> markers, and writes:
#   AGENTS-hot.md        — HOT tier only
#   AGENTS-warm.md       — WARM tier only
#   AGENTS-cold.md       — COLD tier only
#   AGENTS-hot-warm.md   — HOT + WARM combined
#
# --dry-run  : print what would be written, do not write files
# --check    : verify generated files match AGENTS.md markers (exit 1 on mismatch)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$REPO_ROOT/AGENTS.md"
OUT_HOT="$REPO_ROOT/AGENTS-hot.md"
OUT_WARM="$REPO_ROOT/AGENTS-warm.md"
OUT_COLD="$REPO_ROOT/AGENTS-cold.md"
OUT_HOTWARM="$REPO_ROOT/AGENTS-hot-warm.md"

DRY_RUN=0
CHECK_MODE=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --check)   CHECK_MODE=1 ;;
  esac
done

if [[ ! -f "$SOURCE" ]]; then
  echo "ERROR: $SOURCE not found" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Parse AGENTS.md into tier buckets
# ---------------------------------------------------------------------------

declare -a hot_lines warm_lines cold_lines
current_tier=""

while IFS= read -r line; do
  # Detect tier marker
  if [[ "$line" =~ ^[[:space:]]*\<\!--[[:space:]]*@tier:(hot|warm|cold)[[:space:]]*--\>[[:space:]]*$ ]]; then
    current_tier="${BASH_REMATCH[1]}"
    continue  # don't emit the marker line itself
  fi

  case "$current_tier" in
    hot)  hot_lines+=("$line") ;;
    warm) warm_lines+=("$line") ;;
    cold) cold_lines+=("$line") ;;
    # Lines before the first marker (the title line) → hot preamble
    *)    hot_lines+=("$line") ;;
  esac
done < "$SOURCE"

# ---------------------------------------------------------------------------
# Helper: strip trailing blank lines from an array, return via stdout
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Build output strings
# ---------------------------------------------------------------------------

content_hot="$(emit_trimmed hot_lines)"
content_warm="$(emit_trimmed warm_lines)"
content_cold="$(emit_trimmed cold_lines)"
content_hotwarm="$(printf '%s\n\n---\n\n%s' "$content_hot" "$content_warm")"

# ---------------------------------------------------------------------------
# Token size check: hot must be <= 2000 tok (approx chars/3.8)
# ---------------------------------------------------------------------------

HOT_CHARS="${#content_hot}"
HOT_TOK_APPROX=$(( HOT_CHARS / 4 ))   # conservative: 4 chars/tok
if (( HOT_TOK_APPROX > 2000 )); then
  echo "WARNING: AGENTS-hot.md estimated ~${HOT_TOK_APPROX} tok (>${2000} cap). Review tier assignments." >&2
fi

# ---------------------------------------------------------------------------
# Validate: each tier must be non-empty
# ---------------------------------------------------------------------------

errors=0
for tier_name in hot warm cold; do
  var="content_${tier_name}"
  if [[ -z "${!var}" ]]; then
    echo "ERROR: Tier '$tier_name' is empty — check <!-- @tier:${tier_name} --> markers in AGENTS.md" >&2
    (( errors++ ))
  fi
done
(( errors > 0 )) && exit 1

# ---------------------------------------------------------------------------
# Write or check
# ---------------------------------------------------------------------------

write_or_check() {
  local path="$1"
  local content="$2"
  local label="$3"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY] Would write $path (${#content} chars)"
    return
  fi

  if [[ $CHECK_MODE -eq 1 ]]; then
    if [[ ! -f "$path" ]]; then
      echo "FAIL: $path missing (run extract-agents-tier.sh to regenerate)" >&2
      return 1
    fi
    existing="$(cat "$path")"
    if [[ "$existing" != "$content" ]]; then
      echo "FAIL: $path is out of sync with AGENTS.md (run extract-agents-tier.sh to regenerate)" >&2
      return 1
    fi
    echo "OK: $path"
    return 0
  fi

  printf '%s\n' "$content" > "$path"
  echo "Wrote $path (${#content} chars, ~$(( ${#content} / 4 )) tok)"
}

check_failed=0
write_or_check "$OUT_HOT"     "$content_hot"     "hot"      || check_failed=1
write_or_check "$OUT_WARM"    "$content_warm"    "warm"     || check_failed=1
write_or_check "$OUT_COLD"    "$content_cold"    "cold"     || check_failed=1
write_or_check "$OUT_HOTWARM" "$content_hotwarm" "hot+warm" || check_failed=1

if [[ $CHECK_MODE -eq 1 && $check_failed -eq 1 ]]; then
  exit 1
fi

if [[ $DRY_RUN -eq 0 && $CHECK_MODE -eq 0 ]]; then
  echo ""
  echo "Summary:"
  echo "  AGENTS-hot.md      ~$(( ${#content_hot}     / 4 )) tok"
  echo "  AGENTS-warm.md     ~$(( ${#content_warm}    / 4 )) tok"
  echo "  AGENTS-cold.md     ~$(( ${#content_cold}    / 4 )) tok"
  echo "  AGENTS-hot-warm.md ~$(( ${#content_hotwarm} / 4 )) tok"
fi
