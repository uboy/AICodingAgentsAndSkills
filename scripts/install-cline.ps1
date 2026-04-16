<#
.SYNOPSIS
    Install Cline (VSCode plugin) configuration from this project.
#>

param(
    [string]$HomeDir = $env:USERPROFILE,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

$ClineDirs = @(
    "$HomeDir\.vscode\extensions\cline",
    "$HomeDir\.vscode\extensions\saoudrizwan.claude-dev*",
    "$HomeDir\AppData\Roaming\Code\User\globalStorage\saoudrizwan.claude-dev"
)

$TargetDir = $null
foreach ($d in $ClineDirs) {
    if ($d -match '\*') {
        $found = Get-ChildItem -Path (Split-Path $d) -Filter (Split-Path $d -Leaf) -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $TargetDir = $found.FullName; break }
    } elseif (Test-Path $d) {
        $TargetDir = $d; break
    }
}

if (-not $TargetDir) {
    $TargetDir = "$HomeDir\AppData\Roaming\Code\User\globalStorage\saoudrizwan.claude-dev"
    if ($DryRun) {
        Write-Host "[DRY] Cline directory not found; would create: $TargetDir"
    } else {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }
}

$SrcSettings = Join-Path $RepoRoot ".cline\settings.json"

if (-not (Test-Path $SrcSettings)) {
    Write-Host "[SKIP] .cline/settings.json not found in repo" -ForegroundColor Yellow
    exit 0
}

if ($DryRun) {
    Write-Host "[DRY] Would copy $SrcSettings -> $TargetDir\settings.json"
    exit 0
}

$TgtSettings = Join-Path $TargetDir "settings.json"
if (Test-Path $TgtSettings) {
    $Backup = "$TgtSettings.bak"
    Copy-Item $TgtSettings $Backup -Force
    Write-Host "[BACKUP] $TgtSettings -> $Backup" -ForegroundColor Yellow
}

Copy-Item $SrcSettings $TgtSettings -Force
Write-Host "[OK] Installed Cline settings to $TgtSettings" -ForegroundColor Green

Write-Host ""
Write-Host "Note: Cline also needs API keys set:" -ForegroundColor Yellow
Write-Host "  setx ANTHROPIC_API_KEY 'sk-ant-...'"
Write-Host "  setx OPENAI_BASE_URL 'http://your-endpoint/v1'  (if using proxy)"
Write-Host ""
Write-Host "Proxy settings: setx HTTP_PROXY 'http://proxy:port'"
