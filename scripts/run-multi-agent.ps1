param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$WorktreesRoot = "",
    [string]$BaseBranch = "",
    [string[]]$Agents = @("claude", "codex", "gemini"),
    [switch]$IncludeCursor,
    [switch]$IncludeOpenCode,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
    Write-Host "[*] $Message"
}

function Write-Warn([string]$Message) {
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Invoke-Exec([scriptblock]$Script, [string]$Description) {
    if ($DryRun) {
        Write-Host "[DRY] $Description"
        return
    }
    & $Script
}

function Git-Exec([string]$WorkingDir, [string[]]$Args) {
    $output = & git -C $WorkingDir @Args 2>&1
    $exitCode = $LASTEXITCODE
    return [PSCustomObject]@{
        ExitCode = $exitCode
        Output = ($output -join "`n")
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git is required."
}

if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) {
    throw "Repo root not found: $RepoRoot"
}

$isRepoValue = (& git -C $RepoRoot rev-parse --is-inside-work-tree 2>$null)
if ($LASTEXITCODE -ne 0 -or $isRepoValue.Trim() -ne "true") {
    throw "Not a git repository: $RepoRoot"
}

if ([string]::IsNullOrWhiteSpace($WorktreesRoot)) {
    $WorktreesRoot = Join-Path $RepoRoot ".worktrees"
}

if ([string]::IsNullOrWhiteSpace($BaseBranch)) {
    $currentBranch = Git-Exec -WorkingDir $RepoRoot -Args @("branch", "--show-current")
    if ($currentBranch.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($currentBranch.Output.Trim())) {
        $BaseBranch = $currentBranch.Output.Trim()
    } else {
        $symRef = (& git -C $RepoRoot symbolic-ref --short HEAD 2>$null).Trim()
        if (-not [string]::IsNullOrWhiteSpace($symRef)) {
            $BaseBranch = $symRef
        } else {
            $BaseBranch = "main"
        }
    }
}

$agentList = [System.Collections.Generic.List[string]]::new()
foreach ($a in $Agents) {
    if (-not [string]::IsNullOrWhiteSpace($a)) {
        $agentList.Add($a.Trim().ToLowerInvariant())
    }
}
if ($IncludeCursor -and -not $agentList.Contains("cursor")) {
    $agentList.Add("cursor")
}
if ($IncludeOpenCode -and -not $agentList.Contains("opencode")) {
    $agentList.Add("opencode")
}

if ($agentList.Count -eq 0) {
    throw "No agents requested."
}

$coordDirs = @(
    (Join-Path $RepoRoot "coordination"),
    (Join-Path $RepoRoot "coordination\state"),
    (Join-Path $RepoRoot "coordination\handoffs"),
    (Join-Path $RepoRoot "coordination\locks")
)

foreach ($dir in $coordDirs) {
    if (-not (Test-Path -LiteralPath $dir)) {
        Invoke-Exec { New-Item -ItemType Directory -Path $dir -Force | Out-Null } "Create directory: $dir"
    }
}

if (-not (Test-Path -LiteralPath $WorktreesRoot)) {
    Invoke-Exec { New-Item -ItemType Directory -Path $WorktreesRoot -Force | Out-Null } "Create directory: $WorktreesRoot"
}

$baseRef = Git-Exec -WorkingDir $RepoRoot -Args @("rev-parse", "--verify", $BaseBranch)
$baseAvailable = $baseRef.ExitCode -eq 0

Write-Step "Repo root: $RepoRoot"
Write-Step "Base branch: $BaseBranch"
Write-Step "Worktrees root: $WorktreesRoot"
if (-not $baseAvailable) {
    Write-Warn "Base branch has no commits. Worktrees will not be created until initial commit exists."
}

foreach ($agent in $agentList) {
    $branch = "agent/$agent"
    $worktree = if ($baseAvailable) { Join-Path $WorktreesRoot $agent } else { $RepoRoot }
    $stateFile = Join-Path $RepoRoot "coordination\state\$agent.md"

    Write-Step "Prepare agent: $agent"

    if ($baseAvailable) {
        if ((Test-Path -LiteralPath $worktree) -and -not (Test-Path -LiteralPath (Join-Path $worktree ".git"))) {
            Write-Warn "Path exists and is not a git worktree, skipping: $worktree"
            continue
        }

        $branchExists = Git-Exec -WorkingDir $RepoRoot -Args @("show-ref", "--verify", "--quiet", "refs/heads/$branch")

        if (-not (Test-Path -LiteralPath $worktree)) {
            if ($branchExists.ExitCode -eq 0) {
                Invoke-Exec { & git -C $RepoRoot worktree add $worktree $branch | Out-Null } "Create worktree from existing branch: $branch -> $worktree"
            } else {
                Invoke-Exec { & git -C $RepoRoot worktree add -b $branch $worktree $BaseBranch | Out-Null } "Create worktree and branch: $branch from $BaseBranch -> $worktree"
            }
        } else {
            Write-Host "[=] Worktree exists: $worktree"
        }
    }

    if (-not (Test-Path -LiteralPath $stateFile)) {
        $ts = Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ssZ"
        $state = @(
            "# Agent State"
            ""
            "- agent: $agent"
            "- branch: $(if ($baseAvailable) { $branch } else { "uninitialized" })"
            "- task_id: none"
            "- status: idle"
            "- last_updated_utc: $ts"
            "- workspace: $(if ($baseAvailable) { ".worktrees/$agent" } else { "." })"
            "- notes:"
            "  - initialized by scripts/run-multi-agent.ps1"
            "  - $(if ($baseAvailable) { "ready" } else { "create initial commit to enable worktrees" })"
        ) -join "`n"
        Invoke-Exec { Set-Content -LiteralPath $stateFile -Value $state } "Create state file: $stateFile"
    }
}

Write-Host ""
Write-Host "Launch hints:"
foreach ($agent in $agentList) {
    $worktree = if ($baseAvailable) { Join-Path $WorktreesRoot $agent } else { $RepoRoot }
    $cli = switch ($agent) {
        "claude" { "claude" }
        "codex" { "codex" }
        "gemini" { "gemini" }
        "cursor" { "cursor" }
        "opencode" { "opencode" }
        default { $agent }
    }
    Write-Host "- ${agent}: cd `"$worktree`"; $cli"
}

Write-Host ""
Write-Host "Next: use scripts/sync-agents.ps1 to report/sync/integrate agent branches."
