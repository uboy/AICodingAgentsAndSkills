#!/bin/bash
# Install Cline (VSCode plugin) configuration (Linux/macOS).

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

# Try common Cline config locations
CLINE_DIRS=(
    "${HOME_DIR}/.vscode/extensions/cline"
    "${HOME_DIR}/.vscode/extensions/saoudrizwan.claude-dev"
    "${HOME_DIR}/.config/Code/User/globalStorage/saoudrizwan.claude-dev"
)

TARGET_DIR=""
for d in "${CLINE_DIRS[@]}"; do
    if [ -d "$d" ]; then
        TARGET_DIR="$d"
        break
    fi
done

if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR="${HOME_DIR}/.config/Code/User/globalStorage/saoudrizwan.claude-dev"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY] Cline directory not found; would create: $TARGET_DIR"
    else
        mkdir -p "$TARGET_DIR"
    fi
fi

SRC="${REPO_ROOT}/.cline/settings.json"
if [ ! -f "$SRC" ]; then
    echo "[SKIP] .cline/settings.json not found in repo"
    exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY] Would copy $SRC -> $TARGET_DIR/settings.json"
    exit 0
fi

TGT="${TARGET_DIR}/settings.json"
if [ -f "$TGT" ]; then
    backup="${TGT}.bak"
    cp -f "$TGT" "$backup"
    echo "[BACKUP] $TGT -> $backup"
fi

cp -f "$SRC" "$TGT"
echo "[OK] Installed Cline settings to $TGT"

echo ""
echo "Note: Cline also needs API keys set (replace placeholders with your actual keys):"
echo "  export ANTHROPIC_API_KEY='sk-ant-...'"
echo "  export OPENAI_BASE_URL='http://your-endpoint/v1'  (if using proxy)"
echo ""
echo "Proxy settings: export HTTP_PROXY='http://proxy:port'"
