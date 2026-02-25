param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$MapFile = ".scratchpad/repo-map.json",
    [Parameter(Mandatory = $true)]
    [string]$Query,
    [int]$Limit = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$mapPath = Join-Path $RepoRoot $MapFile
if (-not (Test-Path -LiteralPath $mapPath -PathType Leaf)) {
    throw "Repo map not found: $mapPath (run build-repo-map first)"
}

$data = Get-Content -LiteralPath $mapPath -Raw | ConvertFrom-Json
$all = @($data.build_files)

$q = $Query.ToLowerInvariant()
$hits = @($all | Where-Object { $_.ToLowerInvariant().Contains($q) }) | Select-Object -First $Limit

Write-Host ("Query: {0}" -f $Query)
Write-Host ("Matches: {0}" -f $hits.Count)
foreach ($h in $hits) {
    Write-Host ("- {0}" -f $h)
}

if ($hits.Count -eq 0) {
    Write-Host "No matches in build file map. Try a broader query."
}
