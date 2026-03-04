#!/bin/bash
# Spawns a parallel agent in a new terminal window on Linux/macOS.
# Part of the auto-orchestration workflow.

set -e

AGENT_ID=""
ROLE=""
TASK_ID=""
DRY_RUN=0

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --agent-id) AGENT_ID="$2"; shift ;;
        --role) ROLE="$2"; shift ;;
        --task-id) TASK_ID="$2"; shift ;;
        --dry-run) DRY_RUN=1 ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$AGENT_ID" ] || [ -z "$ROLE" ] || [ -z "$TASK_ID" ]; then
    echo "Usage: $0 --agent-id <id> --role <role> --task-id <id> [--dry-run]"
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKTREE="$REPO_ROOT/.worktrees/$AGENT_ID"

if [ ! -d "$WORKTREE" ]; then
    echo "[!] Worktree not found for $AGENT_ID. Attempting to initialize..."
    bash "$REPO_ROOT/scripts/run-multi-agent.sh" --agents "$AGENT_ID"
fi

CLI=$AGENT_ID
case $AGENT_ID in
    claude) CLI="claude" ;;
    codex) CLI="codex" ;;
    gemini) CLI="gemini" ;;
esac

PROMPT="Assume role: ${ROLE}. Resume task: ${TASK_ID}. Execute Startup Ritual: bash scripts/startup-ritual.sh --agent ${AGENT_ID}. Report your status to coordination/state/${AGENT_ID}.md."

LAUNCH_CMD="cd \"${WORKTREE}\" && echo '--- AUTO-ORCHESTRATION: ${AGENT_ID} ---' && ${CLI} \"${PROMPT}\""

if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] Would launch new terminal for ${AGENT_ID} with command:"
    echo "$LAUNCH_CMD"
else
    echo "[*] Spawning ${AGENT_ID} in a new terminal window..."
    
    # Try different terminal emulators
    if command -v gnome-terminal >/dev/null 2>&1; then
        gnome-terminal -- bash -c "$LAUNCH_CMD; exec bash"
    elif command -v xterm >/dev/null 2>&1; then
        xterm -e "bash -c \"$LAUNCH_CMD; exec bash\"" &
    elif command -v tmux >/dev/null 2>&1; then
        tmux split-window -h "bash -c \"$LAUNCH_CMD; exec bash\""
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS Terminal
        osascript -e "tell application \"Terminal\" to do script \"$LAUNCH_CMD\""
    else
        echo "[!] No supported terminal emulator found. Running in background..."
        nohup bash -c "$LAUNCH_CMD" > "$REPO_ROOT/.scratchpad/agent-$AGENT_ID.log" 2>&1 &
    fi
fi
