#!/bin/bash
# Create a feature branch for implementation work.

NAME=""
TYPE="feature"
BASE_BRANCH="master"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --name) NAME="$2"; shift ;;
        --type) TYPE="$2"; shift ;;
        --base) BASE_BRANCH="$2"; shift ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$NAME" ]; then
    echo "Usage: $0 --name <name> [--type feature|fix|experiment] [--base master]"
    exit 1
fi

BRANCH_NAME="${TYPE}/${NAME}"
# Sanitize
BRANCH_NAME=$(echo "$BRANCH_NAME" | sed 's/[^a-zA-Z0-9\/_-]/-/g' | sed 's/\/\+/\//g' | sed 's/\/$//')

cd "$REPO_ROOT" || exit 1

# Check if exists
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
    echo "[!] Branch $BRANCH_NAME already exists. Switching to it."
    git checkout "$BRANCH_NAME"
else
    git fetch origin "$BASE_BRANCH" 2>/dev/null
    if git checkout -b "$BRANCH_NAME" "origin/$BASE_BRANCH" 2>/dev/null; then
        echo "[+] Created branch: $BRANCH_NAME (from $BASE_BRANCH)"
    else
        git checkout "$BASE_BRANCH"
        git checkout -b "$BRANCH_NAME"
        echo "[+] Created branch: $BRANCH_NAME (from local $BASE_BRANCH)"
    fi
fi

echo ""
echo "Agent should work on: $BRANCH_NAME"
echo ""
echo "To merge after completion:"
echo "  git checkout $BASE_BRANCH"
echo "  git merge --squash $BRANCH_NAME"
echo '  git commit -m "<type>: <description>"'
echo "  git push origin $BASE_BRANCH"
echo "  git branch -d $BRANCH_NAME"
