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

# 1. SECURITY: Sanitize inputs (Allow only alphanumeric and hyphens)
if [[ ! "$AGENT_ID" =~ ^[a-zA-Z0-9-]+$ ]]; then echo "Invalid AgentId: $AGENT_ID"; exit 1; fi
if [[ ! "$ROLE" =~ ^[a-zA-Z0-9-]+$ ]]; then echo "Invalid Role: $ROLE"; exit 1; fi
if [[ ! "$TASK_ID" =~ ^[a-zA-Z0-9-]+$ ]]; then echo "Invalid TaskId: $TASK_ID"; exit 1; fi

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

# Construct the launch command
LAUNCH_CMD="cd \"${WORKTREE}\" && echo '--- AUTO-ORCHESTRATION: ${AGENT_ID} ---' && ${CLI} \"${PROMPT}\""

if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] Would launch new terminal for ${AGENT_ID} with command:"
    echo "$LAUNCH_CMD"
    exit 0
fi

echo "[*] Attempting to spawn ${AGENT_ID} in a new terminal window..."

# Try different terminal emulators for Linux
if command -v gnome-terminal >/dev/null 2>&1; then
    gnome-terminal --tab --title="${AGENT_ID}" -- bash -c "$LAUNCH_CMD; exec bash"
elif command -v konsole >/dev/null 2>&1; then
    konsole --new-tab -e bash -c "$LAUNCH_CMD; exec bash"
elif command -v xfce4-terminal >/dev/null 2>&1; then
    xfce4-terminal --title="${AGENT_ID}" -e "bash -c \"$LAUNCH_CMD; exec bash\""
elif command -v alacritty >/dev/null 2>&1; then
    alacritty -t "${AGENT_ID}" -e bash -c "$LAUNCH_CMD; exec bash" &
elif command -v kitty >/dev/null 2>&1; then
    kitty -T "${AGENT_ID}" bash -c "$LAUNCH_CMD; exec bash" &
elif command -v xterm >/dev/null 2>&1; then
    xterm -title "${AGENT_ID}" -e "bash -c \"$LAUNCH_CMD; exec bash\"" &

# macOS Specific
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # Try iTerm first (brittle but standard for macOS users)
    if osascript -e 'application "iTerm" is running' >/dev/null 2>&1; then
         osascript -e "tell application \"iTerm\" to create window with default profile command \"bash -c '$LAUNCH_CMD; exec bash'\""
    else
         osascript -e "tell application \"Terminal\" to do script \"$LAUNCH_CMD\""
    fi

# CLI/Server Multiplexers (only if in active session)
elif [ -n "$TMUX" ] && command -v tmux >/dev/null 2>&1; then
    tmux split-window -h "bash -c \"$LAUNCH_CMD; exec bash\""
elif [ -n "$STY" ] && command -v screen >/dev/null 2>&1; then
    screen -X screen bash -c "$LAUNCH_CMD; exec bash"

else
    # Fallback for hidden agents: Log to file and notify user
    SCRATCHPAD="$REPO_ROOT/.scratchpad"
    mkdir -p "$SCRATCHPAD"
    LOG_FILE="$SCRATCHPAD/agent-${AGENT_ID}.log"
    echo "[!] No supported terminal emulator found. Running in background..."
    echo "[!] To follow progress: tail -f $LOG_FILE"
    nohup bash -c "$LAUNCH_CMD" > "$LOG_FILE" 2>&1 &
fi
