param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$Agent = "opencode"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$tasksFile = Join-Path $RepoRoot "coordination/tasks.jsonl"
$stateFile = Join-Path $RepoRoot ("coordination/state/{0}.md" -f $Agent)

if (-not (Test-Path -LiteralPath $tasksFile -PathType Leaf)) {
    throw "Tasks file not found: $tasksFile"
}

if (-not (Test-Path -LiteralPath $stateFile -PathType Leaf)) {
    throw "State file not found: $stateFile"
}

$taskLines = Get-Content -LiteralPath $tasksFile
$inProgress = New-Object System.Collections.Generic.List[object]

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

$stateRaw = Get-Content -LiteralPath $stateFile -Raw

Write-Host "Startup ritual"
Write-Host ("Agent: {0}" -f $Agent)
Write-Host ("Tasks file: {0}" -f $tasksFile)
Write-Host ("State file: {0}" -f $stateFile)
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
Write-Host "Next action: resume from saved checkpoint in coordination/state/<agent>.md and update state after each micro-step."
