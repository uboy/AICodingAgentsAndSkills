<#
.SYNOPSIS
    Generates a new task record in coordination/tasks.jsonl.
    Supports Manual, AI-assisted, and Direct CLI modes.
#>

param(
    [string]$JsonLine,      # Direct JSON input (for agents)
    [string]$Mode = "1"     # 1: AI, 2: Manual
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$TasksFile = Join-Path $RepoRoot "coordination/tasks.jsonl"

# DIRECT MODE (for agents)
if ($JsonLine) {
    if ($JsonLine -match '\{.*\}') {
        Add-Content -LiteralPath $TasksFile -Value $JsonLine
        Write-Host "SUCCESS: Task added to tasks.jsonl via CLI." -ForegroundColor Green
        exit 0
    } else {
        Write-Error "Invalid JSON format."
        exit 1
    }
}

Write-Host "`n--- AI Agent Task Generator ---" -ForegroundColor Cyan
Write-Host "1. AI Mode (takes a raw idea, researches files, proposes plan)"
Write-Host "2. Manual Mode (standard prompts for all fields)"
if (-not $JsonLine) {
    $Mode = Read-Host "Select Mode (default: 1)"
    if (-not $Mode) { $Mode = "1" }
}

if ($Mode -eq "1") {
    Write-Host "`n[AI MODE] Describe what you want to achieve in free text:" -ForegroundColor Yellow
    $RawIdea = Read-Host "Idea"
    if (-not $RawIdea) { throw "Idea is required." }

    Write-Host "`n--- INSTRUCTION FOR AGENT ---" -ForegroundColor Green
    Write-Host "Use 'task-specifier' skill for: $RawIdea"
    Write-Host "Then run: scripts/generate-task.ps1 -JsonLine '<GENERATED_JSON>'"
    Write-Host "-----------------------------" -ForegroundColor Green
    
    $JsonInput = Read-Host "Paste TASK_JSON here"
    if ($JsonInput -match '\{.*\}') {
        Add-Content -LiteralPath $TasksFile -Value $JsonInput
        Write-Host "SUCCESS: Task added." -ForegroundColor Green
    }
    exit 0
}

# MANUAL MODE
$Title = Read-Host "Task Title"
$Owner = Read-Host "Owner (default: any)"
$Owner = if ($Owner) { $Owner } else { "any" }
$Priority = Read-Host "Priority (default: medium)"
$Priority = if ($Priority) { $Priority } else { "medium" }

$TaskId = "T-" + (Get-Date -Format "yyyyMMdd-HHmmss")
$Task = @{
    id         = $TaskId
    title      = $Title
    owner      = $Owner
    status     = "todo"
    priority   = $Priority
    checklist  = @(@{ id="C-1"; text="Implement change"; status="todo" })
    depends_on = @()
    inputs     = @()
    outputs    = @()
    updated_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

Add-Content -LiteralPath $TasksFile -Value ($Task | ConvertTo-Json -Compress)
Write-Host "SUCCESS: Task $TaskId added." -ForegroundColor Green
