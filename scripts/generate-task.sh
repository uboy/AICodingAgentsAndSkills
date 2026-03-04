#!/bin/bash
# Generates a new task record in coordination/tasks.jsonl.
# Supports Manual, AI-assisted, and Direct CLI modes.

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASKS_FILE="$REPO_ROOT/coordination/tasks.jsonl"

JSON_LINE=""
MODE="1"
TASK_ID=""
TITLE=""
OWNER="any"
PRIORITY="medium"
STATUS="todo"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --json-line) JSON_LINE="$2"; shift ;;
        --mode) MODE="$2"; shift ;;
        --task-id) TASK_ID="$2"; shift ;;
        --title) TITLE="$2"; shift ;;
        --owner) OWNER="$2"; shift ;;
        --priority) PRIORITY="$2"; shift ;;
        --status) STATUS="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# DIRECT JSON MODE
if [ -n "$JSON_LINE" ]; then
    echo "$JSON_LINE" >> "$TASKS_FILE"
    echo "SUCCESS: Task added to tasks.jsonl via JSON."
    exit 0
fi

# NON-INTERACTIVE PARAMETER MODE
if [ -n "$TITLE" ]; then
    if [ -z "$TASK_ID" ]; then
        TASK_ID="T-$(date +%Y%m%d-%H%M%S)"
    fi
    UPDATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    TASK_JSON="{\"id\":\"$TASK_ID\",\"title\":\"$TITLE\",\"owner\":\"$OWNER\",\"status\":\"$STATUS\",\"priority\":\"$PRIORITY\",\"checklist\":[{\"id\":\"C-1\",\"text\":\"Implement change\",\"status\":\"todo\"}],\"depends_on\":[],\"inputs\":[],\"outputs\":[],\"updated_at\":\"$UPDATED_AT\"}"
    
    echo "$TASK_JSON" >> "$TASKS_FILE"
    echo "SUCCESS: Task $TASK_ID added via parameters."
    exit 0
fi

# INTERACTIVE MODE
echo -e "\n--- AI Agent Task Generator ---"
echo "1. AI Mode (takes a raw idea, researches files, proposes plan)"
echo "2. Manual Mode (standard prompts for all fields)"

read -p "Select Mode (default: $MODE): " selected_mode
selected_mode=${selected_mode:-$MODE}

if [ "$selected_mode" == "1" ]; then
    echo -e "\n[AI MODE] Describe what you want to achieve in free text:"
    read -p "Idea: " raw_idea
    if [ -z "$raw_idea" ]; then echo "Idea is required."; exit 1; fi

    echo -e "\n--- INSTRUCTION FOR AGENT ---"
    echo "Use 'task-specifier' skill for: $raw_idea"
    echo "Then run: scripts/generate-task.sh --json-line '<GENERATED_JSON>'"
    echo "-----------------------------"
    
    read -p "Paste TASK_JSON here: " json_input
    if [[ "$json_input" =~ \{.*\} ]]; then
        echo "$json_input" >> "$TASKS_FILE"
        echo "SUCCESS: Task added."
    fi
    exit 0
fi

# MANUAL MODE
read -p "Task Title: " manual_title
read -p "Owner (default: any): " manual_owner
manual_owner=${manual_owner:-any}
read -p "Priority (default: medium): " manual_priority
manual_priority=${manual_priority:-medium}

manual_task_id="T-$(date +%Y%m%d-%H%M%S)"
updated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

manual_task="{\"id\":\"$manual_task_id\",\"title\":\"$manual_title\",\"owner\":\"$manual_owner\",\"status\":\"$status\",\"priority\":\"$manual_priority\",\"checklist\":[{\"id\":\"C-1\",\"text\":\"Implement change\",\"status\":\"todo\"}],\"depends_on\":[],\"inputs\":[],\"outputs\":[],\"updated_at\":\"$updated_at\"}"

echo "$manual_task" >> "$TASKS_FILE"
echo "SUCCESS: Task $manual_task_id added."
