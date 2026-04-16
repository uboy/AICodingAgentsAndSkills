# Fix agent files corrupted by merge conflicts.
# Removes duplicated content blocks (repeated frontmatter + body).

param([switch]$DryRun)

function Fix-File {
    param([string]$Path)

    $lines = Get-Content $Path
    if ($lines.Count -lt 30) { return $false }

    # Find where duplication starts: second occurrence of "---\nname:" or "---\nmodel:"
    $dupStart = -1
    $foundFirstFrontmatter = $false

    for ($i = 0; $i -lt [Math]::Min($lines.Count, 200); $i++) {
        $line = $lines[$i].Trim()
        if ($line -eq "---") {
            if (-not $foundFirstFrontmatter) {
                $foundFirstFrontmatter = $true
            } else {
                # Found second frontmatter start - check if next line is "name:" or "model:"
                if ($i + 1 -lt $lines.Count) {
                    $nextLine = $lines[$i + 1].Trim()
                    if ($nextLine -match '^(name|model|description|color):') {
                        $dupStart = $i
                        break
                    }
                }
            }
        }
    }

    if ($dupStart -gt 0) {
        if ($DryRun) {
            Write-Host "[DRY] $(Split-Path $Path -Leaf): $($lines.Count) -> $dupStart lines"
        } else {
            $clean = $lines[0..($dupStart - 1)]
            # Remove trailing empty lines
            while ($clean.Count -gt 0 -and [string]::IsNullOrWhiteSpace($clean[-1])) {
                $clean = $clean[0..($clean.Count - 2)]
            }
            Set-Content -Path $Path -Value $clean -Encoding utf8
            Write-Host "[FIXED] $(Split-Path $Path -Leaf): $($lines.Count) -> $($clean.Count) lines"
        }
        return $true
    }
    return $false
}

$Fixed = 0

# Fix all .md files that have duplicated content
Get-ChildItem -Recurse -File -Filter "*.md" | Where-Object {
    $_.FullName -notmatch '\\node_modules\\|\\.git\\|\.worktrees\\'
} | ForEach-Object {
    if (Fix-File -Path $_.FullName) {
        $script:Fixed++
    }
}

Write-Host ""
Write-Host "Fixed: $Fixed files"
