<#
.SYNOPSIS
    Create a feature branch for implementation work.

.DESCRIPTION
    Creates a new branch from master (or specified base), pushes to origin,
    and reports the branch name for agents to use.

.PARAMETER Name
    Feature name (without prefix). The branch will be named feature/<name>.

.PARAMETER Type
    Branch type prefix: feature (default), fix, experiment

.PARAMETER BaseBranch
    Branch to create from (default: master)

.PARAMETER RepoRoot
    Repository root directory

.EXAMPLE
    .\scripts\create-feature-branch.ps1 -Name "auth-endpoint"
    .\scripts\create-feature-branch.ps1 -Name "null-check" -Type fix
    .\scripts\create-feature-branch.ps1 -Name "rag-test" -Type experiment
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Name,

    [ValidateSet("feature", "fix", "experiment")]
    [string]$Type = "feature",

    [string]$BaseBranch = "master",

    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Push-Location $RepoRoot
try {
    $BranchName = "$Type/$Name"

    # Sanitize branch name
    $BranchName = $BranchName -replace '[^a-zA-Z0-9/_\-]', '-'
    $BranchName = $BranchName -replace '/+', '/'
    $BranchName = $BranchName.TrimEnd('/')

    # Check if already exists
    $existing = git branch --list "$BranchName" 2>$null
    if ($existing) {
        Write-Host "[!] Branch $BranchName already exists. Switching to it." -ForegroundColor Yellow
        git checkout "$BranchName"
    } else {
        # Fetch latest
        git fetch origin $BaseBranch 2>$null

        # Create branch
        git checkout -b "$BranchName" "origin/$BaseBranch" 2>$null
        if ($LASTEXITCODE -ne 0) {
            # Fallback: create from local base
            git checkout "$BaseBranch"
            git checkout -b "$BranchName"
        }
        Write-Host "[+] Created branch: $BranchName (from $BaseBranch)" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Agent should work on: $BranchName" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To merge after completion:" -ForegroundColor Yellow
    Write-Host "  git checkout $BaseBranch"
    Write-Host "  git merge --squash $BranchName"
    Write-Host '  git commit -m "<type>: <description>"'
    Write-Host "  git push origin $BaseBranch"
    Write-Host "  git branch -d $BranchName"
} finally {
    Pop-Location
}
