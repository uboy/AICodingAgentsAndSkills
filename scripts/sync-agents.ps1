param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$WorktreesRoot = "",
    [string]$BaseBranch = "",
    [string[]]$Agents = @("claude", "codex", "gemini"),
    [switch]$IncludeCursor,
    [switch]$IncludeOpenCode,
    [ValidateSet("report", "sync", "integrate")]
    [string]$Mode = "report",
    [switch]$Fetch,
    [switch]$Rebase,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
    Write-Host "[*] $Message"
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

$baseRef = Git-Exec -WorkingDir $RepoRoot -Args @("rev-parse", "--verify", $BaseBranch)
$baseExists = $baseRef.ExitCode -eq 0

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

if ($Fetch) {
    Invoke-Exec { & git -C $RepoRoot fetch --all --prune | Out-Null } "Fetch all remotes"
}

$rows = New-Object System.Collections.Generic.List[object]

foreach ($agent in $agentList) {
    $branch = "agent/$agent"
    $worktree = Join-Path $WorktreesRoot $agent
    $branchExists = (Git-Exec -WorkingDir $RepoRoot -Args @("show-ref", "--verify", "--quiet", "refs/heads/$branch")).ExitCode -eq 0
    $worktreeExists = Test-Path -LiteralPath $worktree
    $dirty = $false
    $ahead = ""
    $behind = ""
    $notes = [System.Collections.Generic.List[string]]::new()

    if (-not $branchExists) {
        $notes.Add("branch missing")
    }

    if (-not $worktreeExists) {
        $notes.Add("worktree missing")
    } elseif ($branchExists) {
        $status = Git-Exec -WorkingDir $worktree -Args @("status", "--porcelain")
        if ($status.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($status.Output.Trim())) {
            $dirty = $true
            $notes.Add("dirty")
        }

        if ($baseExists) {
            $counts = Git-Exec -WorkingDir $RepoRoot -Args @("rev-list", "--left-right", "--count", "$BaseBranch...$branch")
            if ($counts.ExitCode -eq 0) {
                $parts = $counts.Output.Trim().Split("`t", [System.StringSplitOptions]::RemoveEmptyEntries)
                if ($parts.Count -ge 2) {
                    $behind = $parts[0]
                    $ahead = $parts[1]
                }
            }
        } else {
            $notes.Add("base branch has no commits")
        }

        if ($Mode -eq "sync" -and $Rebase -and -not $dirty) {
            if (-not $baseExists) {
                $notes.Add("skip rebase: base branch has no commits")
            } else {
            Invoke-Exec { & git -C $worktree rebase $BaseBranch | Out-Null } "Rebase $branch onto $BaseBranch"
            $notes.Add("rebased")
            }
        }
    }

    $rows.Add([PSCustomObject]@{
        Agent = $agent
        Branch = $branch
        Worktree = $worktree
        Ahead = $ahead
        Behind = $behind
        Dirty = $dirty
        Notes = ($notes -join ", ")
    })
}

if ($Mode -eq "integrate") {
    if (-not $baseExists) {
        throw "Integration requires a base branch with at least one commit: $BaseBranch"
    }

    $rootStatus = Git-Exec -WorkingDir $RepoRoot -Args @("status", "--porcelain")
    if ($rootStatus.ExitCode -ne 0) {
        throw "Cannot inspect repo status."
    }
    if (-not [string]::IsNullOrWhiteSpace($rootStatus.Output.Trim())) {
        throw "Integration requires a clean repo root working tree."
    }

    Invoke-Exec { & git -C $RepoRoot checkout $BaseBranch | Out-Null } "Checkout base branch: $BaseBranch"

    foreach ($row in $rows) {
        if ([string]::IsNullOrWhiteSpace($row.Ahead) -or $row.Ahead -eq "0") {
            continue
        }
        if ($row.Notes -like "*dirty*") {
            Write-Host "[!] Skip dirty agent branch: $($row.Branch)" -ForegroundColor Yellow
            continue
        }
        Invoke-Exec { & git -C $RepoRoot merge --no-ff $row.Branch } "Merge $($row.Branch) into $BaseBranch"
    }
}

Write-Host ""
Write-Host "Agent sync report"
Write-Host "Mode: $Mode"
Write-Host "Base branch: $BaseBranch"
Write-Host "Worktrees root: $WorktreesRoot"
Write-Host ""

$rows | Sort-Object Agent | Format-Table -AutoSize Agent, Branch, Ahead, Behind, Dirty, Notes
