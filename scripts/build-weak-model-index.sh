#!/usr/bin/env bash
# build-weak-model-index.sh — Create index shell files for weak-model code mapping
# Usage: bash scripts/build-weak-model-index.sh [target-dir]

set -euo pipefail

TARGET_DIR="${1:-.}"
MAP_DIR="coordination/code_map"

# Clean old indexes
rm -f "$MAP_DIR"/*.map.md 2>/dev/null || true
mkdir -p "$MAP_DIR"

# Scan source files
while IFS= read -r -d '' filepath; do
  relpath="${filepath#./}"
  filename="$(basename "$filepath")"
  index_file="$MAP_DIR/${filename}.map.md"

  cat > "$index_file" << EOF
# File: $relpath
## Primary Responsibility: (FILL ME)
## Exports: (LIST CLASSES/FUNCTIONS)
## Imports: (LIST KEY DEPENDENCIES)
## Context: (LINK TO RELATED FILES)
EOF
done < <(find "$TARGET_DIR" -type f \( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" \) \
  ! -path "*/node_modules/*" ! -path "*/dist/*" ! -path "*/.git/*" ! -path "*/.worktrees/*" \
  -print0)

echo "Index shells created in $MAP_DIR/. Now call the agent to fill them file-by-file."
