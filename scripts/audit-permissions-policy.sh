#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
PROFILE_FILE="$REPO_ROOT/policy/tool-permissions-profiles.json"
PROFILE_NAME="default"
APPLY=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --repo-root <path>      Override repository root
  --profile-file <path>   Override profile file
  --profile-name <name>   Profile key in JSON (default: default)
  --apply                 Apply supported fixes
  -h, --help              Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
      PROFILE_FILE="$REPO_ROOT/policy/tool-permissions-profiles.json"
      shift 2
      ;;
    --profile-file)
      PROFILE_FILE="$2"
      shift 2
      ;;
    --profile-name)
      PROFILE_NAME="$2"
      shift 2
      ;;
    --apply)
      APPLY=1
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

if [[ ! -f "$PROFILE_FILE" ]]; then
  echo "Profile file not found: $PROFILE_FILE" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for this script." >&2
  exit 1
fi

if ! jq -e --arg profile "$PROFILE_NAME" '.[$profile]' "$PROFILE_FILE" >/dev/null; then
  echo "Profile '$PROFILE_NAME' not found in $PROFILE_FILE" >&2
  exit 1
fi

fail_count=0

add_result() {
  local target="$1"
  local status="$2"
  local detail="$3"
  printf "%-32s %-6s %s\n" "$target" "$status" "$detail"
  if [[ "$status" == "FAIL" ]]; then
    fail_count=$((fail_count + 1))
  fi
}

echo
echo "Permissions policy audit"
echo "Repo: $REPO_ROOT"
echo "Profile: $PROFILE_NAME"
echo
printf "%-32s %-6s %s\n" "TARGET" "STATUS" "DETAIL"
printf "%-32s %-6s %s\n" "------" "------" "------"

claude_path="$REPO_ROOT/.claude/settings.local.json"
codex_path="$REPO_ROOT/.codex/config.toml"
opencode_path="$REPO_ROOT/.config/opencode/opencode.json"

mapfile -t expected_allow < <(jq -r --arg profile "$PROFILE_NAME" '.[$profile].claude_allow[]' "$PROFILE_FILE")
expected_policy="$(jq -r --arg profile "$PROFILE_NAME" '.[$profile].codex_approval_policy' "$PROFILE_FILE")"
expected_opencode_json="$(jq -c --arg profile "$PROFILE_NAME" '.[$profile].opencode_permission // {}' "$PROFILE_FILE")"

if [[ -f "$claude_path" ]]; then
  current_allow="$(jq -r '.permissions.allow[]? // empty' "$claude_path" 2>/dev/null || true)"
else
  current_allow=""
fi

missing=()
for item in "${expected_allow[@]}"; do
  if ! printf '%s\n' "$current_allow" | grep -Fxq "$item"; then
    missing+=("$item")
  fi
done

if [[ ${#missing[@]} -eq 0 ]]; then
  add_result ".claude/settings.local.json" "PASS" "Allowlist matches profile."
else
  if [[ $APPLY -eq 1 ]]; then
    mkdir -p "$(dirname "$claude_path")"
    tmp="$(mktemp)"
    if [[ -f "$claude_path" ]]; then
      jq --argjson add "$(printf '%s\n' "${missing[@]}" | jq -R . | jq -s .)" \
        '.permissions.allow = ((.permissions.allow // []) + $add | unique)' \
        "$claude_path" > "$tmp"
    else
      jq -n --argjson add "$(printf '%s\n' "${expected_allow[@]}" | jq -R . | jq -s .)" \
        '{permissions:{allow:$add}}' > "$tmp"
    fi
    mv "$tmp" "$claude_path"
    add_result ".claude/settings.local.json" "PASS" "Applied missing allow entries."
  else
    add_result ".claude/settings.local.json" "FAIL" "Missing allow entries."
  fi
fi

if [[ ! -f "$codex_path" ]]; then
  add_result ".codex/config.toml" "FAIL" "File not found."
else
  current_policy="$(grep -E '^[[:space:]]*approval_policy[[:space:]]*=' "$codex_path" | head -n1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
  if [[ "$current_policy" == "$expected_policy" ]]; then
    add_result ".codex/config.toml" "PASS" "approval_policy matches profile."
  else
    if [[ $APPLY -eq 1 ]]; then
      if grep -Eq '^[[:space:]]*approval_policy[[:space:]]*=' "$codex_path"; then
        sed -i.bak -E "s|^[[:space:]]*approval_policy[[:space:]]*=.*$|approval_policy = \"$expected_policy\"|" "$codex_path"
        rm -f "$codex_path.bak"
      else
        printf 'approval_policy = "%s"\n%s' "$expected_policy" "$(cat "$codex_path")" > "$codex_path"
      fi
      add_result ".codex/config.toml" "PASS" "Set approval_policy to '$expected_policy'."
    else
      add_result ".codex/config.toml" "FAIL" "approval_policy is '$current_policy', expected '$expected_policy'."
    fi
  fi
fi

check_opencode() {
  local path="$1"
  local label="$2"

  local count="$(printf '%s' "$expected_opencode_json" | jq 'length')"
  if [[ "$count" -eq 0 ]]; then
    add_result "$label" "PASS" "No OpenCode expectations."
    return
  fi

  local mismatches=()
  local instructions_mismatch=0
  
  # Check instructions sync from repo to home
  if [[ "$label" == "~/*" ]]; then
    local repo_config="$REPO_ROOT/opencode.json"
    if [[ -f "$repo_config" ]]; then
      local repo_inst="$(jq -c '.instructions // []' "$repo_config")"
      local act_inst="$(jq -c '.instructions // []' "$path" 2>/dev/null || echo "[]")"
      if [[ "$repo_inst" != "$act_inst" ]]; then
        instructions_mismatch=1
      fi
    fi
  fi

  while IFS= read -r key; do
    local exp="$(printf '%s' "$expected_opencode_json" | jq -r --arg key "$key" '.[$key]')"
    local act=""
    if [[ -f "$path" ]]; then
      act="$(jq -r --arg key "$key" '.permission[$key] // ""' "$path" 2>/dev/null || true)"
    fi
    if [[ -z "$act" ]]; then
      mismatches+=("$key (missing)")
    elif [[ "$act" != "$exp" ]]; then
      mismatches+=("$key (actual=$act expected=$exp)")
    fi
  done < <(printf '%s' "$expected_opencode_json" | jq -r 'keys[]')

  if [[ ${#mismatches[@]} -eq 0 && $instructions_mismatch -eq 0 ]]; then
    add_result "$label" "PASS" "Permission map and instructions match."
  else
    if [[ $APPLY -eq 1 ]]; then
      mkdir -p "$(dirname "$path")"
      local tmp="$(mktemp)"
      if [[ -f "$path" ]]; then
        jq --argjson add "$expected_opencode_json" '.permission = ((.permission // {}) + $add)' "$path" > "$tmp"
        if [[ $instructions_mismatch -eq 1 ]]; then
          local repo_config="$REPO_ROOT/opencode.json"
          local repo_inst="$(jq -c '.instructions // []' "$repo_config")"
          jq --argjson inst "$repo_inst" '.instructions = $inst' "$tmp" > "$tmp.2" && mv "$tmp.2" "$tmp"
        fi
      else
        local repo_config="$REPO_ROOT/opencode.json"
        local repo_inst="[\"AGENTS.md\"]"
        [[ -f "$repo_config" ]] && repo_inst="$(jq -c '.instructions // ["AGENTS.md"]' "$repo_config")"
        jq -n --argjson add "$expected_opencode_json" --argjson inst "$repo_inst" \
          '{"$schema":"https://opencode.ai/config.json","instructions":$inst,"permission":$add}' > "$tmp"
      fi
      mv "$tmp" "$path"
      add_result "$label" "PASS" "Applied fixes for permissions/instructions."
    else
      local detail="Mismatched permissions"
      [[ $instructions_mismatch -eq 1 ]] && detail="$detail and instructions"
      add_result "$label" "FAIL" "$detail."
    fi
  fi
}

check_opencode "$REPO_ROOT/opencode.json" "opencode.json"
check_opencode "$HOME/.config/opencode/opencode.json" "~/.config/opencode/opencode.json"

echo
if [[ $fail_count -gt 0 && $APPLY -eq 0 ]]; then
  echo "Audit failed: $fail_count target(s) out of policy. Use --apply to auto-fix supported targets."
  exit 1
fi
echo "Audit passed."
