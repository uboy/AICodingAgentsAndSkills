param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Git-Out([string[]]$GitArgs) {
    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & git.exe -C $RepoRoot @GitArgs 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $oldEAP
    return [PSCustomObject]@{
        ExitCode = $code
        Lines = @($out)
    }
}

$inside = Git-Out -GitArgs @("rev-parse", "--is-inside-work-tree")
if ($inside.ExitCode -ne 0) {
    throw "Not a git repository: $RepoRoot"
}

$headCheck = Git-Out -GitArgs @("rev-parse", "--verify", "HEAD")
if ($headCheck.ExitCode -eq 0) {
    $diffA = Git-Out -GitArgs @("diff", "--name-only", "--diff-filter=ACMRTUXB", "HEAD")
    $diffB = Git-Out -GitArgs @("diff", "--cached", "--name-only", "--diff-filter=ACMRTUXB")
} else {
    $diffA = Git-Out -GitArgs @("ls-files", "--others", "--modified", "--exclude-standard")
    $diffB = Git-Out -GitArgs @("diff", "--cached", "--name-only", "--diff-filter=ACMRTUXB")
}

$changed = @(
    $diffA.Lines + $diffB.Lines |
    ForEach-Object { "$_" } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not $_.StartsWith("fatal:") } |
    Select-Object -Unique
)

$issues = New-Object System.Collections.Generic.List[object]
$failCount = 0
$warnCount = 0

function Add-Issue([string]$Severity, [string]$Check, [string]$Detail) {
    $issues.Add([PSCustomObject]@{
        Severity = $Severity
        Check = $Check
        Detail = $Detail
    })
    if ($Severity -eq "FAIL") { $script:failCount++ }
    if ($Severity -eq "WARN") { $script:warnCount++ }
}

if ($changed.Count -eq 0) {
    Add-Issue -Severity "WARN" -Check "changed-files" -Detail "No changed files detected against HEAD."
}

$secretPattern = '(?i)(api[_-]?key|secret|token|password)\s*[:=]\s*["''][^"'']{8,}["'']|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}'
$placeholderPattern = '(?i)(example|sample|dummy|test|changeme|<token>|<secret>|<password>)'
$mergeCheckSkip = @("scripts/install.sh", "scripts/install.ps1")

$skillsChanged = $false

foreach ($rel in $changed) {
    $path = Join-Path $RepoRoot $rel
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        continue
    }

    if ($rel -like "skills/*") {
        $skillsChanged = $true
    }

    if ($rel -notin $mergeCheckSkip) {
        $mergeHit = Select-String -Path $path -Pattern '^(<<<<<<<|=======|>>>>>>>)' -SimpleMatch:$false -ErrorAction SilentlyContinue
        if ($mergeHit) {
            Add-Issue -Severity "FAIL" -Check "merge-markers" -Detail "Conflict markers found in $rel"
        }
    }

    # Speed optimization: skip secret scan for Markdown/Docs
    if ($rel.EndsWith(".md")) {
        continue
    }

    $secretHits = Select-String -Path $path -Pattern $secretPattern -ErrorAction SilentlyContinue
    foreach ($hit in $secretHits) {
        if ($hit.Line -notmatch $placeholderPattern) {
            Add-Issue -Severity "FAIL" -Check "secret-scan" -Detail ("Possible secret in {0}:{1}" -f $rel, $hit.LineNumber)
        }
    }

    if ($rel.EndsWith(".ps1")) {
        $errors = $null
        $tokens = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path), [ref]$tokens, [ref]$errors)
        if ($errors.Count -gt 0) {
            Add-Issue -Severity "FAIL" -Check "ps-parse" -Detail ("PowerShell parse errors in {0}" -f $rel)
        }
    }
}

# Gitleaks (deep secret scan -- complements regex-based secret-scan above)
$gitleaksCmd = Get-Command gitleaks -ErrorAction SilentlyContinue
if ($gitleaksCmd) {
    Push-Location $RepoRoot
    try {
        & gitleaks git --staged --redact --no-banner $RepoRoot 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Add-Issue -Severity "PASS" -Check "gitleaks" -Detail "No secrets detected by gitleaks"
        } else {
            Add-Issue -Severity "FAIL" -Check "gitleaks" -Detail "gitleaks found secrets in staged changes (run: gitleaks git --staged for details)"
        }
    } finally {
        Pop-Location
    }
} else {
    Add-Issue -Severity "WARN" -Check "gitleaks" -Detail "gitleaks not installed -- install: winget install gitleaks.gitleaks (Windows) or brew install gitleaks (macOS/Linux)"
}

$coordinationChanged = @($changed | Where-Object { $_ -like "coordination/handoffs/*" -or $_ -like "coordination/state/*" })
if ($coordinationChanged.Count -gt 0) {
    $validateCoordScript = Join-Path $RepoRoot "scripts/validate-coordination.ps1"
    if (Test-Path -LiteralPath $validateCoordScript -PathType Leaf) {
        & pwsh -NoProfile -File $validateCoordScript -FilesToValidate $coordinationChanged
        if ($LASTEXITCODE -ne 0) {
            Add-Issue -Severity "FAIL" -Check "coordination-validate" -Detail "Coordination artifact validation failed."
        }
    } else {
        Add-Issue -Severity "WARN" -Check "coordination-validate" -Detail "validate-coordination.ps1 not found; skipped."
    }
}

$shFiles = @($changed | Where-Object { "$_".EndsWith(".sh") })
if ($shFiles.Count -gt 0) {
    $bash = Get-Command bash -ErrorAction SilentlyContinue
    if (-not $bash -and (Test-Path "C:\Program Files\Git\bin\bash.exe")) {
        $bash = Get-Item "C:\Program Files\Git\bin\bash.exe"
    }

    if (-not $bash) {
        Add-Issue -Severity "WARN" -Check "bash-parse" -Detail "bash not available; skipped .sh syntax checks."
    } else {
        foreach ($rel in $shFiles) {
            $path = Join-Path $RepoRoot $rel
            $cmd = if ($bash -is [System.Management.Automation.CommandInfo]) { $bash.Source } else { $bash.FullName }
            & $cmd -n $path 2>$null
            if ($LASTEXITCODE -ne 0) {
                Add-Issue -Severity "FAIL" -Check "bash-parse" -Detail ("bash -n failed for {0}" -f $rel)
            }
        }
    }
}

if ($skillsChanged) {
    $validateScript = Join-Path $RepoRoot "scripts/validate-skills.ps1"
    if (Test-Path -LiteralPath $validateScript -PathType Leaf) {
        & pwsh -NoProfile -File $validateScript
        if ($LASTEXITCODE -ne 0) {
            Add-Issue -Severity "FAIL" -Check "skills-validate" -Detail "Skill validation failed."
        }
    } else {
        Add-Issue -Severity "WARN" -Check "skills-validate" -Detail "validate-skills.ps1 not found; skipped."
    }
}

$integrityScript = Join-Path $RepoRoot "scripts/run-integrity-fast.ps1"
if (Test-Path -LiteralPath $integrityScript -PathType Leaf) {
    & $integrityScript -RepoRoot $RepoRoot
    if ($LASTEXITCODE -ne 0) {
        Add-Issue -Severity "FAIL" -Check "integrity-fast" -Detail "run-integrity-fast.ps1 failed."
    }
} else {
    Add-Issue -Severity "FAIL" -Check "integrity-fast" -Detail "scripts/run-integrity-fast.ps1 not found."
}

if ($issues.Count -eq 0) {
    Add-Issue -Severity "PASS" -Check "gate" -Detail "No issues detected."
}

Write-Host ""
Write-Host "Security review gate report"
Write-Host "Repo: $RepoRoot"
Write-Host "Changed files: $($changed.Count)"
Write-Host ""
$issues | Format-Table -AutoSize Severity, Check, Detail
Write-Host ""
Write-Host ("Summary: PASS={0} WARN={1} FAIL={2}" -f (@($issues | Where-Object Severity -eq "PASS").Count), $warnCount, $failCount)

if ($failCount -gt 0) {
    exit 1
}
exit 0
