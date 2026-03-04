<#
.SYNOPSIS
    Generates a new task record in coordination/tasks.jsonl.
    Supports Manual, AI-assisted, and Direct CLI modes.
#>

param(
    [string]$JsonLine,      # Direct JSON input (for agents)
    [string]$Mode = "1",    # 1: AI, 2: Manual
    [string]$TaskId,        # Explicit task ID (e.g. T-20260305-auto-orchestration)
    [string]$Title,         # Task title
    [string]$Owner = "any", # Task owner
    [string]$Priority = "medium", # Task priority
    [string]$Status = "todo",     # Initial status
    [string[]]$Checklist = @("Implement change") # Initial checklist items
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$TasksFile = Join-Path $RepoRoot "coordination/tasks.jsonl"

# DIRECT JSON MODE (for agents passing pre-built objects)
if ($JsonLine) {
    if ($JsonLine -match '\{.*\}') {
        Add-Content -LiteralPath $TasksFile -Value $JsonLine
        Write-Host "SUCCESS: Task added to tasks.jsonl via JSON." -ForegroundColor Green
        exit 0
    } else {
        Write-Error "Invalid JSON format."
        exit 1
    }
}

# NON-INTERACTIVE PARAMETER MODE
if ($Title) {
    if ([string]::IsNullOrWhiteSpace($TaskId)) {
        $TaskId = "T-" + (Get-Date -Format "yyyyMMdd-HHmmss")
    }
    
    $clItems = New-Object System.Collections.Generic.List[object]
    $idx = 1
    foreach ($text in $Checklist) {
        $clItems.Add(@{ id = "C-$idx"; text = $text; status = "todo" })
        $idx++
    }

    $Task = @{
        id         = $TaskId
        title      = $Title
        owner      = $Owner
        status     = $Status
        priority   = $Priority
        checklist  = $clItems.ToArray()
        depends_on = @()
        inputs     = @()
        outputs    = @()
        updated_at = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    }

    $json = $Task | ConvertTo-Json -Compress
    Add-Content -LiteralPath $TasksFile -Value $json
    Write-Host "SUCCESS: Task $TaskId added via parameters." -ForegroundColor Green
    exit 0
}

# INTERACTIVE MODE
Write-Host "`n--- AI Agent Task Generator ---" -ForegroundColor Cyan
Write-Host "1. AI Mode (takes a raw idea, researches files, proposes plan)"
Write-Host "2. Manual Mode (standard prompts for all fields)"

$selectedMode = Read-Host "Select Mode (default: $Mode)"
if ([string]::IsNullOrWhiteSpace($selectedMode)) { $selectedMode = $Mode }

if ($selectedMode -eq "1") {
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
$manualTitle = Read-Host "Task Title"
$manualOwner = Read-Host "Owner (default: any)"
if ([string]::IsNullOrWhiteSpace($manualOwner)) { $manualOwner = "any" }
$manualPriority = Read-Host "Priority (default: medium)"
if ([string]::IsNullOrWhiteSpace($manualPriority)) { $manualPriority = "medium" }

$manualTaskId = "T-" + (Get-Date -Format "yyyyMMdd-HHmmss")
$manualTask = @{
    id         = $manualTaskId
    title      = $manualTitle
    owner      = $manualOwner
    status     = "todo"
    priority   = $manualPriority
    checklist  = @(@{ id="C-1"; text="Implement change"; status="todo" })
    depends_on = @()
    inputs     = @()
    outputs    = @()
    updated_at = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
}

Add-Content -LiteralPath $TasksFile -Value ($manualTask | ConvertTo-Json -Compress)
Write-Host "SUCCESS: Task $manualTaskId added." -ForegroundColor Green
