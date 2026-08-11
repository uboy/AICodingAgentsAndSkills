param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$OutPath = "",
    [switch]$Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutPath)) {
    $OutPath = Join-Path $RepoRoot "deploy/skill-deployment-manifest.tsv"
}

$Python = Get-Command python -ErrorAction SilentlyContinue
if (-not $Python) {
    $Python = Get-Command python3 -ErrorAction SilentlyContinue
}
if (-not $Python) {
    throw "python or python3 is required to generate the skill deployment manifest."
}

$ScriptPath = Join-Path $PSScriptRoot "generate_skill_deployment_manifest.py"
$Args = @(
    $ScriptPath,
    "--repo-root", $RepoRoot,
    "--out", $OutPath
)
if ($Check) {
    $Args += "--check"
}

& $Python.Source @Args
exit $LASTEXITCODE
