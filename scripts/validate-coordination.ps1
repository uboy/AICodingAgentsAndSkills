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
    Write-Host "No local handoffs found; nothing to validate."
    exit 0
}

$files = @(
    if ($FilesToValidate.Count -gt 0) {
        $FilesToValidate |
            Where-Object { $_ -like "coordination/handoffs/*" -and (Test-Path (Join-Path $RepoRoot $_)) } |
            ForEach-Object { Join-Path $RepoRoot $_ }
    } else {
        Get-ChildItem -Path $handoffsDir -Filter "*.md" |
            Where-Object { $_.Name -ne ".gitkeep" } |
            Select-Object -ExpandProperty FullName
    }
)

if ($FilesToValidate.Count -gt 0 -and $files.Count -eq 0) {
    Write-Error "Requested handoff files were not found."
    exit 1
}

if ($files.Count -eq 0) {
    Write-Host "No local handoffs found; nothing to validate."
    exit 0
}

$failCount = 0
$strictCommitReadiness = $FilesToValidate.Count -gt 0

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

    $verificationBody = ""
    $verificationMatch = [regex]::Match($content, '(?s)#{2,3}\s+Verification\s*\r?\n(.*?)(?:\r?\n#{2,3}\s+|$)')
    if ($verificationMatch.Success) {
        $verificationBody = $verificationMatch.Groups[1].Value.Trim()
        if (-not $verificationBody -or $verificationBody -match "<command" -or $verificationBody -match "(?i)\btodo\b") {
            Write-Host "FAIL: $relPath has empty or placeholder ## Verification section." -ForegroundColor Red
            $failCount++
            continue
        }
    } else {
        Write-Host "FAIL: $relPath could not parse ## Verification section body." -ForegroundColor Red
        $failCount++
        continue
    }

    $hasCommitReadiness = [regex]::IsMatch($content, '(?m)^#{2,3}\s+Commit Readiness\s*$')
    if ($strictCommitReadiness -and -not $hasCommitReadiness) {
        Write-Host "FAIL: $relPath is missing ## Commit Readiness section." -ForegroundColor Red
        $failCount++
        continue
    }

    $readinessBody = ""
    $isReadyToCommit = $false
    $isNotCommitReady = $false
    if ($hasCommitReadiness) {
        $readinessMatch = [regex]::Match($content, '(?s)#{2,3}\s+Commit Readiness\s*\r?\n(.*?)(?:\r?\n#{2,3}\s+|$)')
        if ($readinessMatch.Success) {
            $readinessBody = $readinessMatch.Groups[1].Value.Trim()
            if (-not $readinessBody -or $readinessBody -match "(?i)\btodo\b" -or $readinessBody -match "<reason") {
                Write-Host "FAIL: $relPath has empty or placeholder ## Commit Readiness section." -ForegroundColor Red
                $failCount++
                continue
            }
            $isReadyToCommit = $readinessBody -match '(?im)^\s*Ready to commit\.'
            $isNotCommitReady = $readinessBody -match '(?im)^\s*Not commit-ready\.'
            if ($strictCommitReadiness -and -not ($isReadyToCommit -or $isNotCommitReady)) {
                Write-Host "FAIL: $relPath must declare either 'Ready to commit.' or 'Not commit-ready.' in ## Commit Readiness." -ForegroundColor Red
                $failCount++
                continue
            }
        } else {
            Write-Host "FAIL: $relPath could not parse ## Commit Readiness section body." -ForegroundColor Red
            $failCount++
            continue
        }
    }

    $hasDelivery = [regex]::IsMatch($content, '(?m)^#{2,3}\s+Delivery Contract\s*$')
    $hasCommit = [regex]::IsMatch($content, '(?m)^#{2,3}\s+Commit Message\s*$')
    if (-not ($hasDelivery -or $hasCommit)) {
        Write-Host "FAIL: $relPath is missing ## Delivery Contract or ## Commit Message section." -ForegroundColor Red
        $failCount++
        continue
    }

    $commitMatch = [regex]::Match($content, '(?s)#{2,3}\s+(?:Delivery Contract|Commit Message)\s*\r?\n(.*?)(?:\r?\n#{2,3}\s+|$)')
    if ($commitMatch.Success) {
        $commitBody = $commitMatch.Groups[1].Value.Trim()
        if (-not $commitBody -or $commitBody -match "(?i)\btodo\b" -or $commitBody -match "<message>") {
            Write-Host "FAIL: $relPath has empty or placeholder delivery/commit section." -ForegroundColor Red
            $failCount++
        }
    } else {
        Write-Host "FAIL: $relPath could not parse delivery/commit section body." -ForegroundColor Red
        $failCount++
        continue
    }

    if ($strictCommitReadiness) {
        $commitPending = $commitBody -match '(?i)\bCommit pending user approval\b'
        $verificationLines = $verificationBody -split "\r?\n"
        $hasFailedVerification = $verificationLines | Where-Object { $_ -match '(?i)->\s*fail(?:ed)?\b' }
        $hasSecurityGatePass = $verificationLines | Where-Object { $_ -match '(?i)security-review-gate' -and $_ -match '(?i)->\s*pass\b' }

        if ($commitPending) {
            if (-not $isReadyToCommit) {
                Write-Host "FAIL: $relPath claims 'Commit pending user approval' without 'Ready to commit.' in ## Commit Readiness." -ForegroundColor Red
                $failCount++
            }
            if ($hasFailedVerification) {
                Write-Host "FAIL: $relPath claims 'Commit pending user approval' but ## Verification contains failed command(s)." -ForegroundColor Red
                $failCount++
            }
            if (-not $hasSecurityGatePass) {
                Write-Host "FAIL: $relPath claims 'Commit pending user approval' but lacks passing security-review-gate evidence in ## Verification." -ForegroundColor Red
                $failCount++
            }
        }
    }
}

if ($failCount -gt 0) {
    Write-Host "`nCoordination validation FAILED with $failCount error(s)." -ForegroundColor Red
    exit 1
}

Write-Host "Coordination validation PASSED." -ForegroundColor Green
exit 0
