param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$failCount = 0
$warnCount = 0

function Add-Result([string]$Severity, [string]$Check, [string]$Detail) {
    Write-Host ("{0} {1} {2}" -f $Severity, $Check, $Detail)
    if ($Severity -eq "FAIL") { $script:failCount++ }
    if ($Severity -eq "WARN") { $script:warnCount++ }
}

function Get-GitChangedFiles([string]$Root) {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) { return @() }

    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    & git.exe -C $Root rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0) { 
        $ErrorActionPreference = $oldEAP
        return @() 
    }

    & git.exe -C $Root rev-parse --verify HEAD 2>$null
    $hasHead = ($LASTEXITCODE -eq 0)

    $all = New-Object System.Collections.Generic.List[string]
    if ($hasHead) {
        $unstaged = & git.exe -C $Root diff --name-only --diff-filter=ACMRTUXB HEAD 2>$null
        $staged = & git.exe -C $Root diff --cached --name-only --diff-filter=ACMRTUXB 2>$null
        foreach ($line in @($unstaged) + @($staged)) {
            if (-not [string]::IsNullOrWhiteSpace("$line")) { $all.Add("$line") }
        }
    } else {
        $fallback = & git.exe -C $Root ls-files --others --modified --exclude-standard 2>$null
        foreach ($line in @($fallback)) {
            if (-not [string]::IsNullOrWhiteSpace("$line")) { $all.Add("$line") }
        }
    }

    $ErrorActionPreference = $oldEAP
    return @($all | Select-Object -Unique)
}

Write-Host "Fast integrity check"
Write-Host "Repo: $RepoRoot"

$parityScript = Join-Path $RepoRoot "scripts/validate-parity.ps1"
if (-not (Test-Path -LiteralPath $parityScript -PathType Leaf)) {
    Add-Result -Severity "FAIL" -Check "validate-parity" -Detail "Missing scripts/validate-parity.ps1"
} else {
    & $parityScript -RepoRoot $RepoRoot
    if ($LASTEXITCODE -ne 0) {
        Add-Result -Severity "FAIL" -Check "validate-parity" -Detail "validate-parity.ps1 failed."
    }
}

$changed = Get-GitChangedFiles -Root $RepoRoot
if ($changed.Count -gt 0) {
    Add-Result -Severity "PASS" -Check "file-scope" -Detail "Using git-changed files for syntax checks."
    $psTargets = @($changed | Where-Object { $_ -like "*.ps1" } | ForEach-Object { Join-Path $RepoRoot $_ })
    $shTargets = @($changed | Where-Object { $_ -like "*.sh" } | ForEach-Object { Join-Path $RepoRoot $_ })
} else {
    Add-Result -Severity "WARN" -Check "file-scope" -Detail "Git change scope unavailable; checking all scripts/*.ps1 and scripts/*.sh."
    $psTargets = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot "scripts") -File -Filter "*.ps1" | ForEach-Object { $_.FullName })
    $shTargets = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot "scripts") -File -Filter "*.sh" | ForEach-Object { $_.FullName })
}

foreach ($path in $psTargets) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    $errors = $null
    $tokens = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path), [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $rel = [System.IO.Path]::GetRelativePath($RepoRoot, $path)
        Add-Result -Severity "FAIL" -Check "ps-parse" -Detail ("PowerShell parse errors in {0}" -f $rel)
    }
}

$bash = Get-Command bash -ErrorAction SilentlyContinue
if (-not $bash -and (Test-Path "C:\Program Files\Git\bin\bash.exe")) {
    $bash = Get-Item "C:\Program Files\Git\bin\bash.exe"
}

if ($shTargets.Count -gt 0 -and -not $bash) {
    Add-Result -Severity "WARN" -Check "bash-parse" -Detail "bash not available; unable to run .sh syntax checks."
} else {
    foreach ($path in $shTargets) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $cmd = if ($bash -is [System.Management.Automation.CommandInfo]) { $bash.Source } else { $bash.FullName }
        & $cmd -n $path 2>$null
        if ($LASTEXITCODE -ne 0) {
            $rel = [System.IO.Path]::GetRelativePath($RepoRoot, $path)
            Add-Result -Severity "FAIL" -Check "bash-parse" -Detail ("bash -n failed for {0}" -f $rel)
        }
    }
}

$jsonFiles = @(
    ".opencode/opencode.json",
    ".gemini/settings.json"
)
foreach ($rel in $jsonFiles) {
    $path = Join-Path $RepoRoot $rel
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Result -Severity "FAIL" -Check "json-parse" -Detail ("Missing required JSON file: {0}" -f $rel)
        continue
    }
    try {
        [void](Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
    } catch {
        Add-Result -Severity "FAIL" -Check "json-parse" -Detail ("Invalid JSON in {0}" -f $rel)
    }
}

$requiredDirs = @("policy", "coordination/templates")
foreach ($rel in $requiredDirs) {
    $path = Join-Path $RepoRoot $rel
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        Add-Result -Severity "FAIL" -Check "dir-presence" -Detail ("Missing required directory: {0}" -f $rel)
    }
}

if ($failCount -eq 0) {
    Add-Result -Severity "PASS" -Check "integrity-fast" -Detail "All required fast integrity checks passed."
}

$passCount = if ($failCount -eq 0) { 1 } else { 0 }
Write-Host ("Summary: PASS={0} WARN={1} FAIL={2}" -f $passCount, $warnCount, $failCount)

if ($failCount -gt 0) {
    exit 1
}
exit 0
