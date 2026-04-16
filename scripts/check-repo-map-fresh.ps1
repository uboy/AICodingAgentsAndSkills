# Check if repo-map is stale and needs rebuilding.
# Returns exit code 0 if fresh, 1 if stale.

param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$MapFile = ".scratchpad/repo-map.json",
    [int]$MaxAgeMinutes = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

$mapPath = Join-Path $RepoRoot $MapFile

if (-not (Test-Path -LiteralPath $mapPath -PathType Leaf)) {
    Write-Host "STALE: repo-map does not exist"
    exit 1
}

# Check file age
$mapAge = (Get-Date) - (Get-Item $mapPath).LastWriteTime
if ($mapAge.TotalMinutes -gt $MaxAgeMinutes) {
    Write-Host ("STALE: repo-map is {0:0} minutes old (max: {1})" -f $mapAge.TotalMinutes, $MaxAgeMinutes)
    exit 1
}

# Check if files changed since map was built
try {
    $mapTime = (Get-Item $mapPath).LastWriteTime
    $changedFiles = & git -C $RepoRoot diff --name-only --since="$($mapTime.ToString("yyyy-MM-ddTHH:mm:ss"))" 2>$null
    if ($LASTEXITCODE -eq 0 -and $changedFiles.Count -gt 0) {
        Write-Host ("STALE: {0} files changed since repo-map was built" -f $changedFiles.Count)
        exit 1
    }
} catch {}

Write-Host "FRESH: repo-map is current"
exit 0
