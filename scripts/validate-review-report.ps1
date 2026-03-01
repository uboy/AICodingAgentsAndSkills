param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string[]]$FilesToValidate = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$reviewsDir = Join-Path $RepoRoot "coordination/reviews"
if (-not (Test-Path -LiteralPath $reviewsDir -PathType Container)) {
    Write-Error "Missing coordination/reviews directory."
    exit 1
}

if ($FilesToValidate.Count -gt 0) {
    $files = @(
        $FilesToValidate |
        Where-Object { $_ -like "coordination/reviews/*.md" } |
        ForEach-Object { Join-Path $RepoRoot $_ } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
    )
} else {
    $files = @(Get-ChildItem -LiteralPath $reviewsDir -File -Filter "*.md" | Where-Object { $_.Name -ne ".gitkeep" } | ForEach-Object { $_.FullName })
}

if ($files.Count -eq 0) {
    Write-Error "No review report files found."
    exit 1
}

$requiredSections = @("## Scope", "## Findings", "## Verification", "## Residual Risks", "## Approval")
$failCount = 0

foreach ($filePath in $files) {
    $relPath = [System.IO.Path]::GetRelativePath($RepoRoot, $filePath).Replace("\", "/")
    $content = Get-Content -LiteralPath $filePath -Raw

    $missing = @()
    foreach ($section in $requiredSections) {
        if ($content -notmatch [regex]::Escape($section)) {
            $missing += $section
        }
    }
    if ($missing.Count -gt 0) {
        Write-Error ("FAIL: {0} missing section(s): {1}" -f $relPath, ($missing -join ", "))
        $failCount++
        continue
    }

    foreach ($section in @("Findings", "Verification", "Approval")) {
        $match = [regex]::Match($content, "(?s)## $section\s*`r?`n(.*?)(?:`r?`n##|$)")
        if (-not $match.Success) {
            Write-Error ("FAIL: {0} could not parse ## {1}" -f $relPath, $section)
            $failCount++
            continue
        }
        $body = $match.Groups[1].Value.Trim()
        if ([string]::IsNullOrWhiteSpace($body) -or $body -match "(?i)\b(todo|tbd|<placeholder>)\b") {
            Write-Error ("FAIL: {0} has empty or placeholder ## {1}" -f $relPath, $section)
            $failCount++
        }
    }
}

if ($failCount -gt 0) {
    Write-Host "`nReview report validation FAILED with $failCount error(s)." -ForegroundColor Red
    exit 1
}

Write-Host "Review report validation PASSED." -ForegroundColor Green
exit 0
