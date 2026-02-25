<#
.SYNOPSIS
    Validates coordination artifacts (handoffs, plans) for required sections and format.
    Follows AGENTS.md Rule 17 (Delivery Contract) and Rule 21 (Orchestration).

.DESCRIPTION
    Checks all files in coordination/handoffs/ and coordination/state/ for adherence to project standards.
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
    $FilesToValidate | Where-Object { $_ -like "coordination/handoffs/*" -and (Test-Path (Join-Path $RepoRoot $_)) } | ForEach-Object { Join-Path $RepoRoot $_ }
} else {
    Get-ChildItem -Path $handoffsDir -Filter "*.md" | Where-Object { $_.Name -ne ".gitkeep" } | Select-Object -ExpandProperty FullName
}

$failCount = 0

foreach ($filePath in $files) {
    $relPath = $filePath.Replace($RepoRoot, "").TrimStart("").TrimStart("/")
    $content = Get-Content -LiteralPath $filePath -Raw
    
    $requiredSections = @("## Summary", "## Files Touched", "## Verification", "## Commit Message")
    $missing = @()

    foreach ($section in $requiredSections) {
        if ($content -notmatch [regex]::Escape($section)) {
            $missing += $section
        }
    }

    if ($missing.Count -gt 0) {
        Write-Error "FAIL: $relPath is missing required sections: $($missing -join ', ')"
        $failCount++
        continue
    }

    # Verify ## Verification is not empty/placeholder
    $verificationMatch = [regex]::Match($content, "(?s)## Verification\s*?
(.*?)(?:?
##|$)")
    if ($verificationMatch.Success) {
        $verificationBody = $verificationMatch.Groups[1].Value.Trim()
        if (-not $verificationBody -or $verificationBody -match "<command" -or $verificationBody -match "todo") {
            Write-Error "FAIL: $relPath has empty or placeholder ## Verification section."
            $failCount++
        }
    } else {
        Write-Error "FAIL: $relPath could not parse ## Verification section body."
        $failCount++
    }

    # Verify ## Commit Message is not empty/placeholder
    $commitMatch = [regex]::Match($content, "(?s)## Commit Message\s*?
(.*?)(?:?
##|$)")
    if ($commitMatch.Success) {
        $commitBody = $commitMatch.Groups[1].Value.Trim()
        if (-not $commitBody -or $commitBody -match "TODO" -or $commitBody -match "<message>") {
            Write-Error "FAIL: $relPath has empty or placeholder ## Commit Message section."
            $failCount++
        }
    } else {
        Write-Error "FAIL: $relPath could not parse ## Commit Message section body."
        $failCount++
    }
}

if ($failCount -gt 0) {
    Write-Host "`nCoordination validation FAILED with $failCount error(s)." -ForegroundColor Red
    exit 1
}

Write-Host "Coordination validation PASSED." -ForegroundColor Green
exit 0
