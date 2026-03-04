<#
.SYNOPSIS
    Spawns a parallel agent in a new terminal window on Windows.
    Part of the auto-orchestration workflow.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$AgentId,
    
    [Parameter(Mandatory=$true)]
    [string]$Role,
    
    [Parameter(Mandatory=$true)]
    [string]$TaskId,
    
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Worktree = Join-Path $RepoRoot ".worktrees\$AgentId"
if (-not (Test-Path $Worktree)) {
    Write-Host "[!] Worktree not found for $AgentId. Attempting to initialize..." -ForegroundColor Yellow
    & pwsh -NoProfile -File (Join-Path $RepoRoot "scripts\run-multi-agent.ps1") -Agents $AgentId
}

$Cli = switch ($AgentId) {
    "claude" { "claude" }
    "codex" { "codex" }
    "gemini" { "gemini" }
    default { $AgentId }
}

$Prompt = "Assume role: ${Role}. Resume task: ${TaskId}. Execute Startup Ritual: pwsh -NoProfile -File scripts\startup-ritual.ps1 -Agent ${AgentId}. Report your status to coordination/state/${AgentId}.md."

# Construct the launch command for the new PowerShell window
# We use -NoExit so the window stays open if the agent crashes
$LaunchCommand = "cd `"${Worktree}`"; Write-Host '--- AUTO-ORCHESTRATION: ${AgentId} ---' -ForegroundColor Cyan; ${Cli} `"${Prompt}`""

if ($DryRun) {
    Write-Host "[DRY-RUN] Would launch new terminal for ${AgentId} with command:" -ForegroundColor Yellow
    Write-Host $LaunchCommand
} else {
    Write-Host "[*] Spawning ${AgentId} in a new window..." -ForegroundColor Green
    Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", $LaunchCommand
}
