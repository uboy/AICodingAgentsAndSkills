param(
    [ValidateSet("claude", "codex")]
    [string]$Agent = "codex"
)

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$coordDir = Join-Path $root "coordination"
$stateDir = Join-Path $coordDir "state"
$tasksPath = Join-Path $coordDir "tasks.jsonl"
$statePath = Join-Path $stateDir "$Agent.md"

$null = New-Item -ItemType Directory -Path $stateDir -Force
$null = New-Item -ItemType Directory -Path (Join-Path $coordDir "handoffs") -Force
$null = New-Item -ItemType Directory -Path (Join-Path $coordDir "reviews") -Force
$null = New-Item -ItemType Directory -Path (Join-Path $root ".scratchpad") -Force

if (-not (Test-Path $tasksPath)) {
    New-Item -ItemType File -Path $tasksPath | Out-Null
}

if (-not (Test-Path $statePath)) {
    $stateTemplate = @"
# Agent State

- agent: $Agent
- task_id: none
- status: idle
- last_updated_utc: $(Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ssZ")
- notes:
  - State file created by startup ritual.
"@
    Set-Content -Path $statePath -Value $stateTemplate
}

$inProgress = @()
Get-Content -Path $tasksPath | ForEach-Object {
    $line = $_.Trim()
    if ($line.Length -eq 0) {
        return
    }
    try {
        $task = $line | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return
    }
    if ($task.owner -eq $Agent -and $task.status -eq "in_progress") {
        $inProgress += $task
    }
}

Write-Host "[Startup Ritual] Agent: $Agent"
if ($inProgress.Count -eq 0) {
    Write-Host "No in-progress tasks for this agent."
}
else {
    Write-Host "In-progress tasks:"
    foreach ($task in $inProgress) {
        Write-Host " - $($task.id): $($task.title)"
    }
}

Write-Host ""
Write-Host "State file: $statePath"
Get-Content -Path $statePath
