<#
.SYNOPSIS
    Validates coordination artifacts (handoffs, plans) for required sections and format.
    Follows AGENTS.md Rule 17 (Delivery Contract) and Rule 21 (Orchestration).

.DESCRIPTION
    Checks files in coordination/handoffs/ for adherence to project standards.
#>

param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string[]]$FilesToValidate = @() # If empty, validates all files in coordination/handoffs/
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$handoffsDir = Join-Path $RepoRoot "coordination/handoffs/"
if (-not (Test-Path -LiteralPath $handoffsDir -PathType Container)) {
    Write-Warning "Coordination handoffs directory not found: $handoffsDir"
    exit 0
}

$files = if ($FilesToValidate.Count -gt 0) {
    $FilesToValidate |
        Where-Object { $_ -like "coordination/handoffs/*" -and (Test-Path (Join-Path $RepoRoot $_)) } |
        ForEach-Object { Join-Path $RepoRoot $_ }
} else {
    Get-ChildItem -Path $handoffsDir -Filter "*.md" |
        Where-Object { $_.Name -ne ".gitkeep" } |
        Select-Object -ExpandProperty FullName
}

$failCount = 0

foreach ($filePath in $files) {
    $relPath = $filePath.Replace($RepoRoot, "").TrimStart("\", "/")
    $content = Get-Content -LiteralPath $filePath -Raw

    $requiredSections = @("## Summary", "## Files Touched", "## Verification")
    $missing = @()

    foreach ($section in $requiredSections) {
        if ($content -notmatch [regex]::Escape($section)) {
            $missing += $section
        }
    }

    if ($missing.Count -gt 0) {
        Write-Host ("FAIL: {0} is missing required sections: {1}" -f $relPath, ($missing -join ", ")) -ForegroundColor Red
        $failCount++
        continue
    }

    $verificationMatch = [regex]::Match($content, '(?s)## Verification\s*\r?\n(.*?)(?:\r?\n##|$)')
    if ($verificationMatch.Success) {
        $verificationBody = $verificationMatch.Groups[1].Value.Trim()
        if (-not $verificationBody -or $verificationBody -match "<command" -or $verificationBody -match "(?i)\btodo\b") {
            Write-Host "FAIL: $relPath has empty or placeholder ## Verification section." -ForegroundColor Red
            $failCount++
        }
    } else {
        Write-Host "FAIL: $relPath could not parse ## Verification section body." -ForegroundColor Red
        $failCount++
    }

    $hasDelivery = [regex]::IsMatch($content, '(?m)^## Delivery Contract\s*$')
    $hasCommit = [regex]::IsMatch($content, '(?m)^## Commit Message\s*$')
    if (-not ($hasDelivery -or $hasCommit)) {
        Write-Host "FAIL: $relPath is missing ## Delivery Contract or ## Commit Message section." -ForegroundColor Red
        $failCount++
        continue
    }

    $commitMatch = [regex]::Match($content, '(?s)## (?:Delivery Contract|Commit Message)\s*\r?\n(.*?)(?:\r?\n##|$)')
    if ($commitMatch.Success) {
        $commitBody = $commitMatch.Groups[1].Value.Trim()
        if (-not $commitBody -or $commitBody -match "(?i)\btodo\b" -or $commitBody -match "<message>") {
            Write-Host "FAIL: $relPath has empty or placeholder delivery/commit section." -ForegroundColor Red
            $failCount++
        }
    } else {
        Write-Host "FAIL: $relPath could not parse delivery/commit section body." -ForegroundColor Red
        $failCount++
    }
}

if ($failCount -gt 0) {
    Write-Host "`nCoordination validation FAILED with $failCount error(s)." -ForegroundColor Red
    exit 1
}

Write-Host "Coordination validation PASSED." -ForegroundColor Green
exit 0
