#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

fail_count=0
warn_count=0

add_result() {
  local severity="$1"
  local check="$2"
  local detail="$3"
  printf "%s %s %s\n" "$severity" "$check" "$detail"
  case "$severity" in
    FAIL) fail_count=$((fail_count + 1)) ;;
    WARN) warn_count=$((warn_count + 1)) ;;
  esac
}

collect_changed_files() {
  if ! command -v git >/dev/null 2>&1; then
    return 1
  fi
  if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 1
  fi

  if git -C "$REPO_ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
    {
      git -C "$REPO_ROOT" diff --name-only --diff-filter=ACMRTUXB HEAD
      git -C "$REPO_ROOT" diff --cached --name-only --diff-filter=ACMRTUXB
    } | awk 'NF' | sort -u
  else
    git -C "$REPO_ROOT" ls-files --others --modified --exclude-standard | awk 'NF' | sort -u
  fi
}

echo "Fast integrity check"
echo "Repo: $REPO_ROOT"

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  PYTHON_BIN=""
fi

if [[ ! -f "$REPO_ROOT/scripts/validate-parity.sh" ]]; then
  add_result "FAIL" "validate-parity" "Missing scripts/validate-parity.sh"
else
  if ! bash "$REPO_ROOT/scripts/validate-parity.sh"; then
    add_result "FAIL" "validate-parity" "validate-parity.sh failed."
  fi
fi

declare -a changed=()
if mapfile -t changed < <(collect_changed_files); then
  add_result "PASS" "file-scope" "Using git-changed files for syntax checks."
else
  add_result "WARN" "file-scope" "Git change scope unavailable; checking all scripts/*.ps1 and scripts/*.sh."
fi

declare -a ps_targets=()
declare -a sh_targets=()
if [[ ${#changed[@]} -gt 0 ]]; then
  for rel in "${changed[@]}"; do
    [[ -n "$rel" ]] || continue
    if [[ "$rel" == *.ps1 ]]; then
      ps_targets+=("$REPO_ROOT/$rel")
    elif [[ "$rel" == *.sh ]]; then
      sh_targets+=("$REPO_ROOT/$rel")
    fi
  done
else
  while IFS= read -r f; do ps_targets+=("$f"); done < <(find "$REPO_ROOT/scripts" -maxdepth 1 -type f -name "*.ps1" | sort)
  while IFS= read -r f; do sh_targets+=("$f"); done < <(find "$REPO_ROOT/scripts" -maxdepth 1 -type f -name "*.sh" | sort)
fi

# Batch all PS1 files into a single pwsh invocation (one startup = fast)
if [[ ${#ps_targets[@]} -gt 0 ]]; then
  if command -v pwsh >/dev/null 2>&1; then
    tmpscript="$(mktemp --suffix=.ps1)"
    {
      echo '$exitCode = 0'
      for psf in "${ps_targets[@]}"; do
        [[ -f "$psf" ]] || continue
        rel="${psf#$REPO_ROOT/}"
        # Convert POSIX path to Windows path for pwsh
        if command -v cygpath >/dev/null 2>&1; then
          win_psf="$(cygpath -w "$psf")"
        else
          win_psf="$psf"
        fi
        printf '$t=$null; $e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile("%s",[ref]$t,[ref]$e); if ($e.Count -gt 0) { Write-Host "FAIL:%s"; $exitCode = 1 }\n' \
          "$win_psf" "$rel"
      done
      echo 'exit $exitCode'
    } > "$tmpscript"
    ps_output="$(pwsh -NoProfile -File "$tmpscript" 2>/dev/null)" || true
    rm -f "$tmpscript"
    while IFS= read -r line; do
      [[ "$line" == FAIL:* ]] && add_result "FAIL" "ps-parse" "PowerShell parse errors in ${line#FAIL:}"
    done <<< "$ps_output"
  else
    add_result "WARN" "ps-parse" "pwsh not available; unable to parse .ps1 files."
  fi
fi

for shf in "${sh_targets[@]}"; do
  [[ -f "$shf" ]] || continue
  if ! bash -n "$shf" >/dev/null 2>&1; then
    rel="${shf#$REPO_ROOT/}"
    add_result "FAIL" "bash-parse" "bash -n failed for $rel"
  fi
done

for json_rel in "opencode.json" ".gemini/settings.json"; do
  json_path="$REPO_ROOT/$json_rel"
  if [[ ! -f "$json_path" ]]; then
    add_result "WARN" "json-parse" "JSON file not found (optional): $json_rel"
    continue
  fi
  if command -v node >/dev/null 2>&1; then
    if ! node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$json_path" >/dev/null 2>&1; then
      add_result "FAIL" "json-parse" "Invalid JSON in $json_rel"
    fi
  elif [[ -n "$PYTHON_BIN" ]]; then
    if ! "$PYTHON_BIN" -c "import json,sys;json.load(open(sys.argv[1], encoding='utf-8'))" "$json_path" >/dev/null 2>&1; then
      add_result "FAIL" "json-parse" "Invalid JSON in $json_rel"
    fi
  else
    add_result "WARN" "json-parse" "No JSON validator available; skipped $json_rel"
  fi
done

for req_dir in "policy" "coordination/templates"; do
  if [[ ! -d "$REPO_ROOT/$req_dir" ]]; then
    add_result "FAIL" "dir-presence" "Missing required directory: $req_dir"
  fi
done

if [[ $fail_count -eq 0 ]]; then
  add_result "PASS" "integrity-fast" "All required fast integrity checks passed."
  pass_count=1
else
  pass_count=0
fi

echo "Summary: PASS=$pass_count WARN=$warn_count FAIL=$fail_count"
if [[ $fail_count -gt 0 ]]; then
  exit 1
fi
exit 0
