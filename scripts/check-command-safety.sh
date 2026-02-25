#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") \"<command text>\"" >&2
  exit 2
fi

command_text="$1"

declare -a block_patterns=(
  '(curl)[^\n\r]*\|\s*(bash|sh|zsh|pwsh|powershell)\b'
  '(wget)[^\n\r]*\|\s*(bash|sh|zsh|pwsh|powershell)\b'
  '\b(invoke-expression|iex|eval)\b'
  '\bfrombase64string\b[^\n\r]*\|\s*(bash|sh|zsh|pwsh|powershell)\b'
)

declare -a warn_patterns=(
  '\brm[[:space:]]+-rf\b'
  '\bremove-item\b[^\n\r]*-recurse[^\n\r]*-force'
  '\b(del|erase)\b[^\n\r]*/(f|s|q)'
  '\bgit[[:space:]]+reset[[:space:]]+--hard\b'
  '\bformat-(volume|disk)\b'
)

status="SAFE"
reasons=()

for p in "${block_patterns[@]}"; do
  if printf '%s' "$command_text" | grep -Eiq "$p"; then
    status="BLOCK"
    reasons+=("Matched block pattern: $p")
  fi
done

if [[ "$status" != "BLOCK" ]]; then
  for p in "${warn_patterns[@]}"; do
    if printf '%s' "$command_text" | grep -Eiq "$p"; then
      status="WARN"
      reasons+=("Matched warn pattern: $p")
    fi
  done
fi

echo
echo "Command safety check"
echo "Status: $status"
echo "Command: $command_text"
if [[ ${#reasons[@]} -gt 0 ]]; then
  echo "Reasons:"
  for r in "${reasons[@]}"; do
    echo "- $r"
  done
fi

case "$status" in
  SAFE) exit 0 ;;
  WARN) exit 10 ;;
  BLOCK) exit 20 ;;
esac
