# Install .qwen configuration files to user home directory.
param(
    [string]$HomeDir = $env:USERPROFILE,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

$Files = @(
    @{ Source = ".qwen/AGENTS.md"; Target = ".qwen/AGENTS.md" },
    @{ Source = ".qwen/settings.json.template"; Target = ".qwen/settings.json.template" },
    @{ Source = ".qwen/text-editor.md"; Target = ".qwen/text-editor.md" },
    @{ Source = ".qwen/homework-manager.md"; Target = ".qwen/homework-manager.md" },
    @{ Source = ".qwen/docs-writer.md"; Target = ".qwen/docs-writer.md" }
)

foreach ($Entry in $Files) {
    $Src = Join-Path $RepoRoot $Entry.Source
    $Tgt = Join-Path $HomeDir $Entry.Target

    if (-not (Test-Path $Src)) {
        Write-Host "[SKIP] $Src not found" -ForegroundColor Yellow
        continue
    }

    $TgtDir = Split-Path $Tgt
    if (-not (Test-Path $TgtDir)) {
        if ($DryRun) { Write-Host "[DRY] Create dir: $TgtDir"; continue }
        New-Item -ItemType Directory -Path $TgtDir -Force | Out-Null
    }

    if ($DryRun) {
        Write-Host "[DRY] $Src -> $Tgt"
        continue
    }

    if (Test-Path $Tgt) {
        $Backup = "$Tgt.bak"
        Copy-Item $Tgt $Backup -Force
        Write-Host "[BACKUP] $Tgt -> $Backup" -ForegroundColor Yellow
    }

    Copy-Item $Src $Tgt -Force
    Write-Host "[OK] $Src -> $Tgt" -ForegroundColor Green
}

Write-Host ""
Write-Host "Installed .qwen files to $HomeDir\.qwen\" -ForegroundColor Cyan
Write-Host "Note: settings.json is NOT overwritten (user version has OAuth/model)." -ForegroundColor Yellow
Write-Host "      Copy settings.json.template to settings.json and add your model/auth settings." -ForegroundColor Yellow
