$ErrorActionPreference = "Stop"
$globalConfig = Join-Path $env:USERPROFILE ".codex/config.toml"

# Codex canonicalizes the project path using \\?\ prefix on Windows
$rawPath = (Resolve-Path (Get-Location)).Path
if (-not $rawPath.StartsWith("\\?\")) {
    $rawPath = "\\?\$rawPath"
}

# TOML table header key for [projects.'<path>']
$tomlTableKey = "[projects.'$rawPath']"
$trustLine = "trust_level = `"trusted`""

if (-not (Test-Path $globalConfig)) {
    $parent = Split-Path $globalConfig
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Set-Content $globalConfig "$tomlTableKey`n$trustLine`n"
    Write-Host "Created global Codex config with trust for $rawPath"
    exit 0
}

$content = Get-Content $globalConfig -Raw
$escapedKey = [regex]::Escape($rawPath)
if ($content -match $escapedKey) {
    Write-Host "Project $rawPath is already trusted."
    exit 0
}

# Append new [projects.'<path>'] section at end of file
Add-Content $globalConfig "`n$tomlTableKey`n$trustLine`n"
Write-Host "Added $rawPath to global Codex projects trust."
