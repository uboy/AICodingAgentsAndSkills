param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$OutputFile = ".scratchpad/repo-map.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$outPath = Join-Path $RepoRoot $OutputFile
$outDir = Split-Path -Path $outPath -Parent
if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$gitOk = $false
try {
    $isRepo = (& git -C $RepoRoot rev-parse --is-inside-work-tree 2>$null)
    if ($LASTEXITCODE -eq 0 -and $isRepo.Trim() -eq "true") {
        $gitOk = $true
    }
} catch {
    $gitOk = $false
}

if ($gitOk) {
    $files = @(& git -C $RepoRoot ls-files)
} else {
    $files = Get-ChildItem -Path $RepoRoot -Recurse -File | ForEach-Object {
        $_.FullName.Substring($RepoRoot.Length).TrimStart('\\', '/')
    }
}

$patterns = @(
    "BUILD.gn", "*.gn", "*.gni", "*.ninja", "build.ninja",
    "CMakeLists.txt", "*.cmake", "Makefile", "GNUmakefile", "*.mk",
    "package.json", "pnpm-workspace.yaml", "pyproject.toml", "setup.py",
    "requirements*.txt", "*.sh", "*.ps1"
)

function Match-Any([string]$path, [string[]]$globPatterns) {
    foreach ($p in $globPatterns) {
        if ($path -like $p) {
            return $true
        }
        if ($path -like "*/$p") {
            return $true
        }
    }
    return $false
}

$buildFiles = @($files | Where-Object { Match-Any $_ $patterns })

$entrypoints = @($buildFiles | Where-Object {
    $_ -match "(^|/)(build\\.ninja|BUILD\\.gn|CMakeLists\\.txt|Makefile|package\\.json)$"
})

$result = [PSCustomObject]@{
    generated_at_utc = (Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ssZ")
    repo_root = $RepoRoot
    total_files = $files.Count
    build_files_count = $buildFiles.Count
    build_entrypoints = $entrypoints
    build_files = $buildFiles
}

$json = $result | ConvertTo-Json -Depth 5
Set-Content -LiteralPath $outPath -Value $json -Encoding UTF8

Write-Host "Repo map written: $outPath"
Write-Host ("Build files: {0}" -f $buildFiles.Count)
Write-Host ("Entrypoints: {0}" -f $entrypoints.Count)
