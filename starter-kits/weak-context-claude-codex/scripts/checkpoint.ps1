param(
    [ValidateSet("claude", "codex")]
    [string]$Agent = "codex",
    [Parameter(Mandatory = $true)]
    [string]$TaskId,
    [ValidateSet("todo", "in_progress", "blocked", "done", "idle")]
    [string]$Status = "in_progress",
    [string]$Note = "Checkpoint updated."
)

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$stateDir = Join-Path $root "coordination/state"
$statePath = Join-Path $stateDir "$Agent.md"
$null = New-Item -ItemType Directory -Path $stateDir -Force

$updatedAt = Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ssZ"
$content = @"
# Agent State

- agent: $Agent
- task_id: $TaskId
- status: $Status
- last_updated_utc: $updatedAt
- workspace: $root
- notes:
  - $Note
"@

Set-Content -Path $statePath -Value $content
Write-Host "Updated checkpoint: $statePath"
