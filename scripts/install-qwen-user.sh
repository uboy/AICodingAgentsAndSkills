#!/bin/bash
# Install .qwen configuration files to user home directory (Linux/macOS).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${HOME}"
DRY_RUN=0

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --home-dir) HOME_DIR="$2"; shift ;;
        --dry-run) DRY_RUN=1 ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

FILES=(
    "out/.qwen/AGENTS.md:.qwen/AGENTS.md"
)

INSTALLED=0

for entry in "${FILES[@]}"; do
    src_rel="${entry%%:*}"
    tgt_rel="${entry##*:}"
    src="${REPO_ROOT}/${src_rel}"
    tgt="${HOME_DIR}/${tgt_rel}"

    if [ ! -f "$src" ]; then
        echo "[SKIP] $src not found"
        continue
    fi

    tgt_dir="$(dirname "$tgt")"
    if [ ! -d "$tgt_dir" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "[DRY] Create dir: $tgt_dir"
            continue
        fi
        mkdir -p "$tgt_dir"
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY] $src -> $tgt"
        continue
    fi

    if [ -f "$tgt" ]; then
        backup="${tgt}.bak"
        cp -f "$tgt" "$backup"
        echo "[BACKUP] $tgt -> $backup"
    fi

    cp -f "$src" "$tgt"
    echo "[OK] $src -> $tgt"
    INSTALLED=$((INSTALLED + 1))
done

echo ""
echo "Installed $INSTALLED .qwen files to ${HOME_DIR}/.qwen/"
echo "Note: current generated Qwen support in this checkout deploys only AGENTS.md."
