#!/usr/bin/env bash
set -euo pipefail

INPUT_FILE=""
MODE="compact"

usage() {
  cat <<EOF
Usage: $(basename "$0") --input-file <path> [--mode compact|full]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input-file)
      INPUT_FILE="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
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

if [[ -z "$INPUT_FILE" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Input file not found: $INPUT_FILE" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for this script." >&2
  exit 1
fi

total="$(jq -R -s 'split("\n") | map(select(length > 0) | fromjson? ) | length' "$INPUT_FILE")"
failed="$(jq -R -s 'split("\n") | map(select(length > 0) | fromjson? | select(.status != "ok" and .status != "pass")) | length' "$INPUT_FILE")"
writes="$(jq -R -s 'split("\n") | map(select(length > 0) | fromjson? | select(.effect == "write")) | length' "$INPUT_FILE")"
network="$(jq -R -s 'split("\n") | map(select(length > 0) | fromjson? | select(.effect == "network")) | length' "$INPUT_FILE")"

if [[ "$MODE" == "compact" ]]; then
  echo "Tool Use Summary (compact)"
  echo "- total: $total"
  echo "- failed: $failed"
  echo "- write actions: $writes"
  echo "- network actions: $network"
  if [[ "$failed" -gt 0 ]]; then
    echo "- failed commands:"
    jq -R -s '
      split("\n")
      | map(select(length > 0) | fromjson?)
      | map(select(.status != "ok" and .status != "pass"))
      | .[:3]
      | .[] | "  - \(.tool): \(.command)"' -r "$INPUT_FILE"
  fi
  exit 0
fi

if [[ "$MODE" != "full" ]]; then
  echo "Invalid mode: $MODE" >&2
  exit 1
fi

echo "Tool Use Summary (full)"
jq -R -s '
  split("\n")
  | map(select(length > 0) | fromjson?)
  | .[]
  | [.tool, .effect, .status, .command] | @tsv' -r "$INPUT_FILE" \
  | awk 'BEGIN { printf "%-14s %-10s %-8s %s\n","TOOL","EFFECT","STATUS","COMMAND"; printf "%-14s %-10s %-8s %s\n","----","------","------","-------" } { printf "%-14s %-10s %-8s %s\n",$1,$2,$3,substr($0,index($0,$4)) }'
