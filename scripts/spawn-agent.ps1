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

# 1. SECURITY: Sanitize inputs (Allow only alphanumeric and hyphens)
$SanityRegex = "^[a-zA-Z0-9\-]+$"
if ($AgentId -notmatch $SanityRegex) { throw "Invalid AgentId: $AgentId" }
if ($Role -notmatch $SanityRegex) { throw "Invalid Role: $Role" }
if ($TaskId -notmatch $SanityRegex) { throw "Invalid TaskId: $TaskId" }

$Worktree = Join-Path $RepoRoot ".worktrees\$AgentId"

$Cli = switch ($AgentId) {
    "claude" { "claude" }
    "codex" { "codex" }
    "gemini" { "gemini" }
    default { $AgentId }
}

$Prompt = "Assume role: ${Role}. Resume task: ${TaskId}. Execute Startup Ritual: pwsh -NoProfile -File scripts\startup-ritual.ps1 -Agent ${AgentId}. Report your status to coordination/state/${AgentId}.md."

# Construct the launch command
$LaunchCommand = "cd `"${Worktree}`"; Write-Host '--- AUTO-ORCHESTRATION: ${AgentId} ---' -ForegroundColor Cyan; ${Cli} `"${Prompt}`""

if ($DryRun) {
    if (-not (Test-Path $Worktree)) {
        Write-Host "[DRY-RUN] Worktree missing for ${AgentId}; would initialize via scripts\\run-multi-agent.ps1." -ForegroundColor Yellow
    }
    Write-Host "[DRY-RUN] Would launch new terminal for ${AgentId} with command:" -ForegroundColor Yellow
    Write-Host $LaunchCommand
    exit 0
}

if (-not (Test-Path $Worktree)) {
    Write-Host "[!] Worktree not found for $AgentId. Attempting to initialize..." -ForegroundColor Yellow
    & pwsh -NoProfile -File (Join-Path $RepoRoot "scripts\run-multi-agent.ps1") -Agents $AgentId
}

Write-Host "[*] Attempting to spawn ${AgentId} in a new window..." -ForegroundColor Green

$Spawned = $false
try {
    # Try Windows Terminal (wt.exe) first for better experience (tabs)
    if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
        Start-Process wt.exe -ArgumentList "nt", "-d", "`"${Worktree}`"", "powershell.exe", "-NoExit", "-Command", $LaunchCommand
        $Spawned = $true
    } else {
        Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", $LaunchCommand
        $Spawned = $true
    }
} catch {
    Write-Host "[!] Failed to open terminal window: $($_.Exception.Message)" -ForegroundColor Red
}

if (-not $Spawned) {
    # 2. POLICY COMPLIANCE: Fallback to logging for headless/failed environments
    $Scratchpad = Join-Path $RepoRoot ".scratchpad"
    if (-not (Test-Path $Scratchpad)) { New-Item -ItemType Directory -Path $Scratchpad | Out-Null }
    
    $LogFile = Join-Path $Scratchpad "agent-${AgentId}.log"
    Write-Host "[!] Falling back to background execution..." -ForegroundColor Yellow
    Write-Host "[!] To follow progress: Get-Content -Wait `"$LogFile`"" -ForegroundColor Cyan
    
    # Run in background and redirect output
    Start-Process powershell.exe -ArgumentList "-Command", "$LaunchCommand > `"$LogFile`" 2>&1" -WindowStyle Hidden
}
