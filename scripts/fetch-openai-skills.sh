#!/bin/bash
# Fetches and distributes skills from the OpenAI Skills repository.
# Repo: https://github.com/openai/skills

set -e

TARGET_DIR="skills"
REPO_URL="https://github.com/openai/skills"
FORCE=0
DRY_RUN=0

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --force) FORCE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --target-dir) TARGET_DIR="$2"; shift ;;
        --repo-url) REPO_URL="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t 'openai-skills')"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "--- OpenAI Skills Fetcher ---"

# 1. Fetch
if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] Would clone $REPO_URL to temporary directory."
else
    echo "Cloning $REPO_URL..."
    git clone --depth 1 "$REPO_URL" "$TEMP_DIR" > /dev/null 2>&1
fi

# 2. Process Skills
for folder in "$TEMP_DIR"/*; do
    [ -d "$folder" ] || continue
    skill_name="$(basename "$folder")"
    [[ "$skill_name" == .* ]] && continue

    dest_path="$REPO_ROOT/$TARGET_DIR/$skill_name"
    manifest_path="$folder/SKILL.md"

    if [ ! -f "$manifest_path" ]; then
        echo "Skipping $skill_name: No SKILL.md found."
        continue
    fi

    if [ -d "$dest_path" ]; then
        if [ "$FORCE" -eq 1 ]; then
            echo "Overwriting existing skill: $skill_name"
        else
            echo "Skill already exists, skipping: $skill_name (use --force to overwrite)"
            continue
        fi
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY-RUN] Would copy skill: $skill_name to $TARGET_DIR/$skill_name"
    else
        echo "Installing skill: $skill_name"
        mkdir -p "$(dirname "$dest_path")"
        cp -r "$folder" "$dest_path"
    fi
done

echo -e "\nDistribution complete."
