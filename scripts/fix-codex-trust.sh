#!/bin/bash
set -e

GLOBAL_CONFIG="$HOME/.codex/config.toml"
PROJECT_PATH="$(pwd)"
# TOML table header and value for [projects.'<path>']
TOML_HEADER="[projects.'${PROJECT_PATH}']"
TRUST_LINE='trust_level = "trusted"'

if [ ! -f "$GLOBAL_CONFIG" ]; then
    mkdir -p "$(dirname "$GLOBAL_CONFIG")"
    printf '%s\n%s\n' "$TOML_HEADER" "$TRUST_LINE" > "$GLOBAL_CONFIG"
    echo "Created global Codex config with trust for $PROJECT_PATH"
    exit 0
fi

if grep -qF "$PROJECT_PATH" "$GLOBAL_CONFIG"; then
    echo "Project $PROJECT_PATH is already trusted."
    exit 0
fi

# Append new [projects.'<path>'] section at end of file
printf '\n%s\n%s\n' "$TOML_HEADER" "$TRUST_LINE" >> "$GLOBAL_CONFIG"
echo "Added $PROJECT_PATH to global Codex projects trust."
