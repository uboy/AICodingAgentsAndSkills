#!/bin/bash
# Check if repo-map is stale and needs rebuilding.
# Returns exit code 0 if fresh, 1 if stale.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAP_FILE="${REPO_ROOT}/.scratchpad/repo-map.json"
MAX_AGE_MINUTES="${2:-30}"

if [ ! -f "$MAP_FILE" ]; then
    echo "STALE: repo-map does not exist"
    exit 1
fi

# Check file age
MAP_AGE_SEC=$(( ($(date +%s) - $(stat -c %Y "$MAP_FILE" 2>/dev/null || stat -f %m "$MAP_FILE" 2>/dev/null || echo 0)) ))
MAX_AGE_SEC=$((MAX_AGE_MINUTES * 60))

if [ "$MAP_AGE_SEC" -gt "$MAX_AGE_SEC" ]; then
    echo "STALE: repo-map is $((MAP_AGE_SEC / 60)) minutes old (max: ${MAX_AGE_MINUTES})"
    exit 1
fi

# Check if files changed since map was built
MAP_TIME=$(stat -c %Y "$MAP_FILE" 2>/dev/null || stat -f %m "$MAP_FILE" 2>/dev/null || echo 0)
if [ "$MAP_TIME" -gt 0 ]; then
    CHANGED=$(git -C "$REPO_ROOT" diff --name-only --since="@${MAP_TIME}" 2>/dev/null | wc -l)
    if [ "$CHANGED" -gt 0 ]; then
        echo "STALE: $CHANGED files changed since repo-map was built"
        exit 1
    fi
fi

echo "FRESH: repo-map is current"
exit 0
