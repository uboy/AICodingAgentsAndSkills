#!/bin/bash
# Fix agent files corrupted by merge conflicts (Linux/macOS).
# Removes duplicated content blocks (repeated frontmatter + body).

DRY_RUN=0
while [[ "$#" -gt 0 ]]; do
    case $1 in --dry-run) DRY_RUN=1 ;; esac; shift
done

FIXED=0

fix_file() {
    local path="$1"
    local lines=()
    local i=0

    while IFS= read -r line; do
        lines+=("$line")
    done < "$path"

    local count=${#lines[@]}
    if [ "$count" -lt 30 ]; then return 0; fi

    local found_first=0
    local dup_start=-1

    for ((i=0; i<200 && i<count; i++)); do
        local trimmed="${lines[$i]#"${lines[$i]%%[![:space:]]*}"}"
        if [ "$trimmed" = "---" ]; then
            if [ "$found_first" -eq 0 ]; then
                found_first=1
            else
                if [ $((i+1)) -lt "$count" ]; then
                    local next="${lines[$((i+1))]#"${lines[$((i+1))]%%[![:space:]]*}"}"
                    if [[ "$next" =~ ^(name|model|description|color): ]]; then
                        dup_start=$i
                        break
                    fi
                fi
            fi
        fi
    done

    if [ "$dup_start" -gt 0 ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "[DRY] $(basename "$path"): $count -> $dup_start lines"
        else
            # Remove trailing empty lines
            local end=$((dup_start - 1))
            while [ "$end" -gt 0 ] && [ -z "${lines[$end]// /}" ]; do
                end=$((end - 1))
            done
            printf '%s\n' "${lines[@]:0:$((end+1))}" > "$path"
            echo "[FIXED] $(basename "$path"): $count -> $((end+1)) lines"
        fi
        return 1
    fi
    return 0
}

while IFS= read -r -d '' f; do
    fix_file "$f"
    FIXED=$((FIXED + $?))
done < <(find . -name "*.md" -type f -not -path "./.git/*" -not -path "./.worktrees/*" -print0)

echo ""
echo "Fixed: $FIXED files"
