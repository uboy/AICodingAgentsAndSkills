param(
    [Parameter(Mandatory = $true)]
    [string]$Title,
    [ValidateSet("claude", "codex")]
    [string]$Owner = "codex",
    [string]$TaskId = "",
    [ValidateSet("low", "medium", "high")]
    [string]$Priority = "medium"
)

if ([string]::IsNullOrWhiteSpace($TaskId)) {
    $TaskId = "T-" + (Get-Date -AsUTC -Format "yyyyMMdd-HHmmss")
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$tasksPath = Join-Path $root "coordination/tasks.jsonl"
$tasksDir = Split-Path $tasksPath
$null = New-Item -ItemType Directory -Path $tasksDir -Force
if (-not (Test-Path $tasksPath)) {
    New-Item -ItemType File -Path $tasksPath | Out-Null
}

$updatedAt = Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ssZ"
$task = @{
    id = $TaskId
    title = $Title
    owner = $Owner
    status = "todo"
    priority = $Priority
    checklist = @(
        @{
            id = "C-1"
            text = "Execute one micro-step and verify acceptance"
            status = "todo"
        },
        @{
            id = "C-2"
            text = "Run syntax/lint/tests for this micro-step"
            status = "todo"
        },
        @{
            id = "C-3"
            text = "Update state and handoff"
            status = "todo"
        }
    )
    depends_on = @()
    inputs = @()
    outputs = @()
    profile = "weak_model"
    updated_at = $updatedAt
}

$line = $task | ConvertTo-Json -Compress -Depth 6

Add-Content -Path $tasksPath -Value $line
Write-Host "Added task $TaskId to $tasksPath"
