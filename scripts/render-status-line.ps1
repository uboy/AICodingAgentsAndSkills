param(
    [string]$System = "unknown",
    [string]$RepoRoot = "",
    [string]$InputJson = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

function Resolve-RepoRoot([string]$Hint) {
    if (-not [string]::IsNullOrWhiteSpace($Hint)) {
        $tasks = Join-Path $Hint "coordination\tasks.jsonl"
        if (Test-Path -LiteralPath $tasks -PathType Leaf) {
            return (Resolve-Path -LiteralPath $Hint).Path
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:AI_AGENT_REPO_ROOT)) {
        $tasks = Join-Path $env:AI_AGENT_REPO_ROOT "coordination\tasks.jsonl"
        if (Test-Path -LiteralPath $tasks -PathType Leaf) {
            return (Resolve-Path -LiteralPath $env:AI_AGENT_REPO_ROOT).Path
        }
    }

    $dir = (Get-Location).Path
    while ($true) {
        $tasks = Join-Path $dir "coordination\tasks.jsonl"
        if (Test-Path -LiteralPath $tasks -PathType Leaf) {
            return $dir
        }
        $parent = Split-Path -Path $dir -Parent
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $dir) {
            break
        }
        $dir = $parent
    }

    return ""
}

function Parse-StateValue([string]$Path, [string]$Key) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
    $lines = Get-Content -LiteralPath $Path
    foreach ($line in $lines) {
        if ($line -match "^\s*-\s*${Key}:\s*`?([^`]+)`?\s*$") {
            return $Matches[1].Trim()
        }
    }
    return ""
}

function Parse-Tasks([string]$Path) {
    $items = @()
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $items }
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        $trim = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trim)) { continue }
        try {
            $items += ($trim | ConvertFrom-Json)
        } catch {
            continue
        }
    }
    return $items
}

function Select-ActiveTask($tasks, [string]$agent) {
    $ordered = @($tasks)
    [Array]::Reverse($ordered)
    foreach ($t in $ordered) {
        if ($t.status -eq "in_progress" -and ($t.owner -eq $agent -or $t.owner -eq "any")) {
            return $t
        }
    }
    foreach ($t in $ordered) {
        if ($t.status -eq "in_progress") { return $t }
    }
    return $null
}

function Shorten([string]$text, [int]$maxLen = 28) {
    if ([string]::IsNullOrWhiteSpace($text)) { return "-" }
    $clean = ($text -replace "\s+", " ").Trim()
    if ($clean.Length -le $maxLen) { return $clean }
    return $clean.Substring(0, $maxLen - 1) + "…"
}

if ([string]::IsNullOrWhiteSpace($InputJson)) {
    try {
        if ([Console]::IsInputRedirected) {
            $InputJson = [Console]::In.ReadToEnd()
        }
    } catch {}
}

$root = Resolve-RepoRoot -Hint $RepoRoot
$agent = $System
$skill = "-"
$taskId = "-"
$step = "-"
$done = 0
$total = 0

if (-not [string]::IsNullOrWhiteSpace($root)) {
    $statePath = Join-Path $root ("coordination\state\{0}.md" -f $System)
    $parsedAgent = Parse-StateValue -Path $statePath -Key "agent"
    if (-not [string]::IsNullOrWhiteSpace($parsedAgent)) {
        $agent = $parsedAgent
    }
    $parsedSkill = Parse-StateValue -Path $statePath -Key "skill"
    if (-not [string]::IsNullOrWhiteSpace($parsedSkill)) {
        $skill = $parsedSkill
    }

    $tasks = Parse-Tasks -Path (Join-Path $root "coordination\tasks.jsonl")
    $active = Select-ActiveTask -tasks $tasks -agent $agent
    if ($null -ne $active) {
        if ($active.id) { $taskId = [string]$active.id }
        $items = @($active.checklist)
        $total = $items.Count
        foreach ($c in $items) {
            if ($c.status -eq "done") { $done += 1 }
        }
        $current = $items | Where-Object { $_.status -eq "in_progress" } | Select-Object -First 1
        if (-not $current) {
            $current = $items | Where-Object { $_.status -eq "todo" } | Select-Object -First 1
        }
        if (-not $current -and $items.Count -gt 0) {
            $current = $items[-1]
        }
        if ($current -and $current.text) {
            $step = [string]$current.text
        }
    }
}

$model = $System
$ctx = "-"
if (-not [string]::IsNullOrWhiteSpace($InputJson)) {
    try {
        $obj = $InputJson | ConvertFrom-Json
        if ($obj.model.display_name) {
            $model = [string]$obj.model.display_name
        }
        if ($obj.context_window.used_percentage -ne $null -and "$($obj.context_window.used_percentage)" -ne "") {
            $ctx = ("{0:0}%" -f [double]$obj.context_window.used_percentage)
        }
    } catch {}
}

$line = "{0} | ag:{1} | sk:{2} | step:{3} | chk:{4}/{5} | task:{6} | ctx:{7}" -f `
    (Shorten $model 20), `
    (Shorten $agent 12), `
    (Shorten $skill 14), `
    (Shorten $step 28), `
    $done, `
    $total, `
    (Shorten $taskId 18), `
    $ctx

Write-Output $line
