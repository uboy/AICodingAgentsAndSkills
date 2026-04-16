<#
.SYNOPSIS
    Update agent checkpoint state file.

.DESCRIPTION
    Writes structured state to coordination/state/<agent>.md and optionally
    updates the task checklist in coordination/tasks.jsonl.

.PARAMETER Agent
    Agent name (e.g., implementation-developer, wm-implementer)

.PARAMETER TaskId
    Task identifier from tasks.jsonl

.PARAMETER Status
    Current status: idle, in_progress, done, blocked, error, rate_limited

.PARAMETER Action
    Brief description of the last action taken

.PARAMETER Note
    Additional context or decision notes

.PARAMETER NextAction
    What should happen next

.PARAMETER RetryCount
    Number of retries for the current action (for loop detection)

.EXAMPLE
    .\scripts\agent-checkpoint.ps1 -Agent implementation-developer -TaskId T-001 -Status in_progress -Action "edited src/auth.py" -Note "Added null guard"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Agent,

    [Parameter(Mandatory=$true)]
    [string]$TaskId,

    [ValidateSet("idle", "in_progress", "done", "blocked", "error", "rate_limited")]
    [string]$Status = "in_progress",

    [string]$Action = "",
    [string]$Note = "",
    [string]$NextAction = "",
    [int]$RetryCount = 0,
    [string]$ConsecutiveSameAction = "",
    [string]$ActionResult = "",

    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$StateDir = Join-Path $RepoRoot "coordination/state"
if (-not (Test-Path $StateDir)) {
    New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
}

$StateFile = Join-Path $StateDir "$Agent.md"
$UpdatedAt = Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ssZ"

$content = @"
# Agent State

- agent: $Agent
- task_id: $TaskId
- status: $Status
- last_updated_utc: $UpdatedAt
- workspace: $RepoRoot
- last_action: $Action
- last_action_result: $ActionResult
- next_action: $NextAction
- retry_count: $RetryCount
- consecutive_same_action: $ConsecutiveSameAction
- notes:
  - $Note
"@

Set-Content -Path $StateFile -Value $content -Encoding utf8
Write-Host "[checkpoint] $Agent | $TaskId | $Status | $Action" -ForegroundColor Cyan

# Update tasks.jsonl if TaskId is provided and file exists
$TasksFile = Join-Path $RepoRoot "coordination/tasks.jsonl"
if ($TaskId -and (Test-Path $TasksFile)) {
    $lines = Get-Content $TasksFile
    $newLines = @()
    $found = $false
    foreach ($line in $lines) {
        try {
            $obj = $line | ConvertFrom-Json
            if ($obj.id -eq $TaskId) {
                $obj.status = $Status
                $obj.updated_at = $UpdatedAt
                # Update checklist items if transitioning
                if ($Status -eq "done" -and $obj.checklist) {
                    foreach ($c in $obj.checklist) {
                        if ($c.status -eq "in_progress") { $c.status = "done" }
                    }
                }
                if ($Status -eq "in_progress" -and $obj.checklist) {
                    # Mark first todo as in_progress
                    $first = $obj.checklist | Where-Object { $_.status -eq "todo" } | Select-Object -First 1
                    if ($first) { $first.status = "in_progress" }
                }
                $newLines += ($obj | ConvertTo-Json -Compress -Depth 3)
                $found = $true
            } else {
                $newLines += $line
            }
        } catch {
            $newLines += $line
        }
    }

    if (-not $found) {
        # Create new task entry
        $newTask = @{
            id = $TaskId
            title = $Action
            owner = $Agent
            status = $Status
            checklist = @()
            updated_at = $UpdatedAt
        }
        $newLines += ($newTask | ConvertTo-Json -Compress -Depth 3)
    }

    $newLines | Set-Content -Path $TasksFile -Encoding utf8
    Write-Host "[checkpoint] tasks.jsonl updated for $TaskId" -ForegroundColor DarkGray
}
