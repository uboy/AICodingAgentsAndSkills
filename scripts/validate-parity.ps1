param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string[]]$IgnoredBasenames = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptsDir = Join-Path $RepoRoot "scripts"
if (-not (Test-Path -LiteralPath $scriptsDir -PathType Container)) {
    Write-Host "FAIL scripts-dir Scripts directory not found: $scriptsDir"
    exit 1
}

$failCount = 0
$warnCount = 0

function Add-Result([string]$Severity, [string]$Check, [string]$Detail) {
    Write-Host ("{0} {1} {2}" -f $Severity, $Check, $Detail)
    if ($Severity -eq "FAIL") { $script:failCount++ }
    if ($Severity -eq "WARN") { $script:warnCount++ }
}

$ignoreSet = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
foreach ($name in $IgnoredBasenames) {
    if (-not [string]::IsNullOrWhiteSpace($name)) {
        [void]$ignoreSet.Add($name.Trim())
    }
}

$psFiles = Get-ChildItem -LiteralPath $scriptsDir -File -Filter "*.ps1" | Sort-Object Name
$shFiles = Get-ChildItem -LiteralPath $scriptsDir -File -Filter "*.sh" | Sort-Object Name

$psNames = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
$shNames = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

foreach ($f in $psFiles) { [void]$psNames.Add([System.IO.Path]::GetFileNameWithoutExtension($f.Name)) }
foreach ($f in $shFiles) { [void]$shNames.Add([System.IO.Path]::GetFileNameWithoutExtension($f.Name)) }

foreach ($name in $psNames | Sort-Object) {
    if ($ignoreSet.Contains($name)) { continue }
    if (-not $shNames.Contains($name)) {
        Add-Result -Severity "FAIL" -Check "script-parity" -Detail ("Missing scripts/{0}.sh (paired with scripts/{0}.ps1)" -f $name)
    }
}

foreach ($name in $shNames | Sort-Object) {
    if ($ignoreSet.Contains($name)) { continue }
    if (-not $psNames.Contains($name)) {
        Add-Result -Severity "FAIL" -Check "script-parity" -Detail ("Missing scripts/{0}.ps1 (paired with scripts/{0}.sh)" -f $name)
    }
}

$adapterFiles = @(
    "CLAUDE.md",
    ".codex/AGENTS.md",
    "CURSOR.md",
    "GEMINI.md",
    "OPENCODE.md",
    ".opencode/AGENTS.md",
    ".gemini/AGENTS.md"
)

foreach ($rel in $adapterFiles) {
    $path = Join-Path $RepoRoot $rel
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Result -Severity "FAIL" -Check "adapter-presence" -Detail ("Missing required adapter file: {0}" -f $rel)
        continue
    }

    $lines = Get-Content -LiteralPath $path
    $lineCount = @($lines).Count
    $hasAgentsRef = ($lines -join "`n") -match "AGENTS(-hot|-warm|-cold|-hot-warm)?\.md"
    if (-not $hasAgentsRef) {
        Add-Result -Severity "FAIL" -Check "adapter-thin" -Detail ("{0} must reference AGENTS.md (or a tier file: AGENTS-hot.md, AGENTS-warm.md, etc.)" -f $rel)
    }
    if ($lineCount -gt 40) {
        Add-Result -Severity "FAIL" -Check "adapter-thin" -Detail ("{0} has {1} lines; expected <= 40" -f $rel, $lineCount)
    }
}

if ($failCount -eq 0) {
    Add-Result -Severity "PASS" -Check "parity" -Detail "Cross-OS and cross-system parity checks passed."
}

Write-Host ("Summary: PASS={0} WARN={1} FAIL={2}" -f $(if ($failCount -eq 0) { 1 } else { 0 }), $warnCount, $failCount)
if ($failCount -gt 0) {
    exit 1
}
exit 0
