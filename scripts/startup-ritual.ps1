param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$Agent = "opencode"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$tasksFile = Join-Path $RepoRoot "coordination/tasks.jsonl"
$stateDir = Join-Path $RepoRoot "coordination/state"
$stateFile = Join-Path $stateDir ("{0}.md" -f $Agent)
$stateTemplateFile = Join-Path $RepoRoot "coordination/templates/state.md"
$sessionUsageFile = Join-Path $stateDir "session-usage.json"

function New-StateFileContent([string]$AgentName) {
    $timestamp = Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ssZ"
    if (Test-Path -LiteralPath $stateTemplateFile -PathType Leaf) {
        $template = Get-Content -LiteralPath $stateTemplateFile -Raw
        $template = $template -replace [regex]::Escape("<name>"), $AgentName
        $template = $template -replace [regex]::Escape("1970-01-01T00:00:00Z"), $timestamp
        return $template
    }

    return @(
        "# Agent State"
        ""
        "- agent: $AgentName"
        "- branch: agent/$AgentName"
        "- task_id: none"
        "- status: idle"
        "- last_updated_utc: $timestamp"
        "- workspace: .worktrees/$AgentName"
        "- notes:"
        "  - bootstrapped by scripts/startup-ritual.ps1"
    ) -join "`n"
}

function New-SessionUsageContent([string]$AgentName) {
    $timestamp = Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ssZ"
    $payload = [ordered]@{
        _comment                    = "Per-session usage tracker. Updated by agents. See policy/subscription-limits-policy.md"
        session_id                  = ("{0}-{1}" -f $timestamp.Replace(":", "").Replace("-", ""), $AgentName)
        agent                       = $AgentName
        session_start_utc           = $timestamp
        last_checkpoint_utc         = $timestamp
        estimated_tokens_used       = 0
        estimated_usage_percent     = 0
        gate_tokens_since_last_confirm = 0
        auto_resume_attempts        = 0
        status                      = "idle"
        resume_after_utc            = $null
        last_completed_step         = "none"
        next_step                   = "startup"
    }
    return ($payload | ConvertTo-Json -Depth 4)
}

if (-not (Test-Path -LiteralPath $stateDir -PathType Container)) {
    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $stateFile -PathType Leaf)) {
    Set-Content -LiteralPath $stateFile -Value (New-StateFileContent -AgentName $Agent)
}

if (-not (Test-Path -LiteralPath $sessionUsageFile -PathType Leaf)) {
    Set-Content -LiteralPath $sessionUsageFile -Value (New-SessionUsageContent -AgentName $Agent)
}

$inProgress = New-Object System.Collections.Generic.List[object]
if (Test-Path -LiteralPath $tasksFile -PathType Leaf) {
    $taskLines = Get-Content -LiteralPath $tasksFile
    foreach ($line in $taskLines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        try {
            $obj = $line | ConvertFrom-Json
        } catch {
            continue
        }

        $owner = ""
        if ($obj.PSObject.Properties.Name -contains "owner") {
            $owner = [string]$obj.owner
        }

        if ([string]$obj.status -eq "in_progress" -and ($owner -eq $Agent -or $owner -eq "any")) {
            $inProgress.Add($obj)
        }
    }
}

$stateRaw = Get-Content -LiteralPath $stateFile -Raw

Write-Host "Startup ritual"
Write-Host ("Agent: {0}" -f $Agent)
Write-Host ("Tasks file: {0}" -f $(if (Test-Path -LiteralPath $tasksFile -PathType Leaf) { $tasksFile } else { "$tasksFile (not initialized; local tracker optional)" }))
Write-Host ("State file: {0}" -f $stateFile)
Write-Host ("Session usage file: {0}" -f $sessionUsageFile)
Write-Host ""

Write-Host ("In-progress tasks for {0}: {1}" -f $Agent, $inProgress.Count)
foreach ($t in $inProgress) {
    $id = if ($t.PSObject.Properties.Name -contains "id") { [string]$t.id } else { "<no-id>" }
    $title = if ($t.PSObject.Properties.Name -contains "title") { [string]$t.title } else { "<no-title>" }
    Write-Host ("- {0}: {1}" -f $id, $title)
}

Write-Host ""
Write-Host "Current state snapshot:"
foreach ($key in @("task_id", "status", "last_updated_utc", "workspace")) {
    $m = [regex]::Match($stateRaw, ("(?m)^- {0}:\s*`?([^`\r\n]+)`?\s*$" -f [regex]::Escape($key)))
    if ($m.Success) {
        Write-Host ("- {0}: {1}" -f $key, $m.Groups[1].Value)
    }
}

Write-Host ""
Write-Host "Next action: resume from saved checkpoint in coordination/state/<agent>.md and update state after each micro-step. If no local tasks.jsonl exists yet, continue with state + scratchpad only."
