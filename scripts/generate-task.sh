#!/usr/bin/env bash
set -euo pipefail

# SYNOPSIS
#     Generates a new task record in coordination/tasks.jsonl.
#     Supports Manual, AI-assisted, and Direct CLI modes.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TASKS_FILE="$REPO_ROOT/coordination/tasks.jsonl"

# DIRECT CLI MODE
if [[ "${1:-}" == "--json" || "${1:-}" == "-j" ]]; then
    JSON_LINE="$2"
    if [[ "$JSON_LINE" =~ \{.*\} ]]; then
        echo "$JSON_LINE" >> "$TASKS_FILE"
        echo "SUCCESS: Task added via CLI."
        exit 0
    else
        echo "Error: Invalid JSON format."
        exit 1
    fi
fi

echo -e "\n--- AI Agent Task Generator ---"
echo "1. AI Mode (default)"
echo "2. Manual Mode"
read -p "Select Mode: " MODE
MODE=${MODE:-1}

if [[ "$MODE" == "1" ]]; then
    echo -e "\n[AI MODE] Describe what you want to achieve in free text:"
    read -p "Idea: " RAW_IDEA
    if [[ -z "$RAW_IDEA" ]]; then
        echo "Error: Idea is required."
        exit 1
    fi

    echo -e "\n--- INSTRUCTION FOR AGENT ---"
    echo "Use 'task-specifier' skill for: $RAW_IDEA"
    echo "Then run: scripts/generate-task.sh --json '<GENERATED_JSON>'"
    echo "-----------------------------"
    
    echo -e "\nPaste the TASK_JSON block here:"
    read -r JSON_INPUT
    
    if [[ "$JSON_INPUT" =~ \{.*\} ]]; then
        echo "$JSON_INPUT" >> "$TASKS_FILE"
        echo "SUCCESS: Task added."
    else
        echo "Error: Invalid JSON format."
        exit 1
    fi
    exit 0
fi

# MANUAL MODE
read -p "Task Title: " TITLE
if [[ -z "$TITLE" ]]; then
  echo "Error: Title required."
  exit 1
fi

TASK_ID="T-$(date +%Y%m%d-%H%M%S)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Simple JSON generation as fallback
echo "{\"id\":\"$TASK_ID\",\"title\":\"$TITLE\",\"owner\":\"any\",\"status\":\"todo\",\"priority\":\"medium\",\"checklist\":[{\"id\":\"C-1\",\"text\":\"Implement change\",\"status\":\"todo\"}],\"depends_on\":[],\"inputs\":[],\"outputs\":[],\"updated_at\":\"$TIMESTAMP\"}" >> "$TASKS_FILE"

echo -e "\nSUCCESS: Task $TASK_ID added."
