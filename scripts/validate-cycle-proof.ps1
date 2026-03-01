param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$ContractFile = "coordination/cycle-contract.json",
    [string]$ApprovalFile = "coordination/approval-overrides.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Git-Out([string[]]$GitArgs) {
    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & git.exe -C $RepoRoot @GitArgs 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $oldEAP
    return [PSCustomObject]@{
        ExitCode = $code
        Lines = @($out)
    }
}

function Normalize-RelPath([string]$RelPath) {
    return ($RelPath -replace "\\", "/").TrimStart("/")
}

$issues = New-Object System.Collections.Generic.List[object]
$failCount = 0
$warnCount = 0
$passCount = 0

function Add-Issue([string]$Severity, [string]$Check, [string]$Detail) {
    $issues.Add([PSCustomObject]@{
        Severity = $Severity
        Check = $Check
        Detail = $Detail
    })
    if ($Severity -eq "FAIL") { $script:failCount++ }
    if ($Severity -eq "WARN") { $script:warnCount++ }
    if ($Severity -eq "PASS") { $script:passCount++ }
}

$inside = Git-Out -GitArgs @("rev-parse", "--is-inside-work-tree")
if ($inside.ExitCode -ne 0) {
    throw "Not a git repository: $RepoRoot"
}

$contractPath = Join-Path $RepoRoot $ContractFile
if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    Add-Issue -Severity "FAIL" -Check "contract-file" -Detail "Missing cycle contract file: $ContractFile"
} else {
    try {
        $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json -AsHashtable
        Add-Issue -Severity "PASS" -Check "contract-file" -Detail "Loaded cycle contract: $ContractFile"
    } catch {
        Add-Issue -Severity "FAIL" -Check "contract-file" -Detail "Invalid JSON in $ContractFile"
        $contract = $null
    }
}

if (-not $contract) {
    Write-Host ""
    Write-Host "Cycle-proof validation report"
    $issues | Format-Table -AutoSize Severity, Check, Detail
    Write-Host ""
    Write-Host ("Summary: PASS={0} WARN={1} FAIL={2}" -f $passCount, $warnCount, $failCount)
    exit 1
}

foreach ($field in @("task_id", "implementation_agent", "review_agent", "required_commands", "required_artifacts", "limits")) {
    if (-not $contract.ContainsKey($field)) {
        Add-Issue -Severity "FAIL" -Check "contract-schema" -Detail "Missing field in cycle contract: $field"
    }
}

$requiredWin = @()
if ($contract.required_commands -and $contract.required_commands.windows) {
    $requiredWin = @($contract.required_commands.windows)
}
if ($requiredWin.Count -eq 0) {
    Add-Issue -Severity "FAIL" -Check "contract-schema" -Detail "required_commands.windows must contain at least one command."
}

$reviewPathRel = Normalize-RelPath "$($contract.required_artifacts.review_report)"
$handoffPathRel = Normalize-RelPath "$($contract.required_artifacts.handoff_report)"

$headCheck = Git-Out -GitArgs @("rev-parse", "--verify", "HEAD")
if ($headCheck.ExitCode -eq 0) {
    $diffA = Git-Out -GitArgs @("diff", "--name-only", "--diff-filter=ACMRTUXB", "HEAD")
    $diffB = Git-Out -GitArgs @("diff", "--cached", "--name-only", "--diff-filter=ACMRTUXB")
    $diffC = Git-Out -GitArgs @("ls-files", "--others", "--exclude-standard")
    $numStat = Git-Out -GitArgs @("diff", "--numstat", "HEAD")
} else {
    $diffA = Git-Out -GitArgs @("ls-files", "--others", "--modified", "--exclude-standard")
    $diffB = Git-Out -GitArgs @("diff", "--cached", "--name-only", "--diff-filter=ACMRTUXB")
    $diffC = [PSCustomObject]@{ ExitCode = 0; Lines = @() }
    $numStat = [PSCustomObject]@{ ExitCode = 0; Lines = @() }
}

$changed = @(
    $diffA.Lines + $diffB.Lines + $diffC.Lines |
    ForEach-Object { Normalize-RelPath "$_" } |
    Where-Object {
        -not [string]::IsNullOrWhiteSpace($_) -and
        -not $_.StartsWith("fatal:") -and
        -not $_.StartsWith("warning:")
    } |
    Select-Object -Unique
)

$functionalPatterns = @(
    "scripts/*",
    "policy/*",
    "configs/*",
    "deploy/*",
    ".claude/*",
    ".codex/*",
    ".gemini/*",
    ".cursor/*",
    ".opencode/*",
    ".cursorrules",
    "AGENTS.md",
    "AGENTS-hot.md",
    "AGENTS-warm.md",
    "AGENTS-cold.md",
    "AGENTS-hot-warm.md",
    "CLAUDE.md",
    "CURSOR.md",
    "GEMINI.md",
    "OPENCODE.md",
    "opencode.json",
    "templates/git/pre-commit",
    "skills/*",
    "commands/*",
    "evals/*"
)
$nonFunctional = @(
    "coordination/tasks.jsonl",
    "coordination/state/*",
    "coordination/handoffs/*",
    "coordination/reviews/*",
    ".scratchpad/*",
    "coordination/change-scope.txt"
)

function Test-Match([string]$Path, [string[]]$Patterns) {
    foreach ($p in $Patterns) {
        if ($Path -like $p) { return $true }
    }
    return $false
}

$functionalChanged = @(
    $changed | Where-Object {
        (Test-Match -Path $_ -Patterns $functionalPatterns) -and
        (-not (Test-Match -Path $_ -Patterns $nonFunctional))
    }
)

$approvalPath = Join-Path $RepoRoot $ApprovalFile
$allowLargeChanges = $false
if (Test-Path -LiteralPath $approvalPath -PathType Leaf) {
    try {
        $approval = Get-Content -LiteralPath $approvalPath -Raw | ConvertFrom-Json -AsHashtable
        if ($approval.ContainsKey("allow_large_changes")) {
            $allowLargeChanges = [bool]$approval.allow_large_changes
        }
    } catch {
        Add-Issue -Severity "WARN" -Check "approval-file" -Detail "Could not parse $ApprovalFile; defaulting allow_large_changes=false."
    }
}

$diffLines = 0
foreach ($line in $numStat.Lines) {
    $parts = "$line".Split("`t")
    if ($parts.Count -lt 3) { continue }
    $add = $parts[0]
    $del = $parts[1]
    if ($add -match '^\d+$') { $diffLines += [int]$add }
    if ($del -match '^\d+$') { $diffLines += [int]$del }
}
$untracked = Git-Out -GitArgs @("ls-files", "--others", "--exclude-standard")
foreach ($rel in $untracked.Lines | ForEach-Object { Normalize-RelPath "$_" } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) {
    $full = Join-Path $RepoRoot $rel
    if (Test-Path -LiteralPath $full -PathType Leaf) {
        try { $diffLines += @(Get-Content -LiteralPath $full).Count } catch {}
    }
}

$maxFiles = [int]$contract.limits.max_functional_files
$maxDiff = [int]$contract.limits.max_diff_lines
if ($functionalChanged.Count -gt $maxFiles) {
    if ($allowLargeChanges) {
        Add-Issue -Severity "WARN" -Check "iteration-size" -Detail ("Functional files changed {0} > {1}, allowed by override." -f $functionalChanged.Count, $maxFiles)
    } else {
        Add-Issue -Severity "FAIL" -Check "iteration-size" -Detail ("Functional files changed {0} > {1}. Split task or enable approved override." -f $functionalChanged.Count, $maxFiles)
    }
} else {
    Add-Issue -Severity "PASS" -Check "iteration-size" -Detail ("Functional files changed {0} <= {1}" -f $functionalChanged.Count, $maxFiles)
}

if ($diffLines -gt $maxDiff) {
    if ($allowLargeChanges) {
        Add-Issue -Severity "WARN" -Check "diff-size" -Detail ("Diff lines {0} > {1}, allowed by override." -f $diffLines, $maxDiff)
    } else {
        Add-Issue -Severity "FAIL" -Check "diff-size" -Detail ("Diff lines {0} > {1}. Split task or enable approved override." -f $diffLines, $maxDiff)
    }
} else {
    Add-Issue -Severity "PASS" -Check "diff-size" -Detail ("Diff lines {0} <= {1}" -f $diffLines, $maxDiff)
}

$reviewPath = Join-Path $RepoRoot $reviewPathRel
if (-not (Test-Path -LiteralPath $reviewPath -PathType Leaf)) {
    Add-Issue -Severity "FAIL" -Check "review-artifact" -Detail "Required review report not found: $reviewPathRel"
} else {
    $reviewText = Get-Content -LiteralPath $reviewPath -Raw
    if ($reviewText -notmatch [regex]::Escape($contract.task_id)) {
        Add-Issue -Severity "FAIL" -Check "review-artifact" -Detail "Review report does not reference task_id: $($contract.task_id)"
    } else {
        Add-Issue -Severity "PASS" -Check "review-artifact" -Detail "Review report references task_id."
    }
    foreach ($cmd in $requiredWin) {
        if ($reviewText -notmatch [regex]::Escape("$cmd")) {
            Add-Issue -Severity "FAIL" -Check "review-commands" -Detail "Missing required command in review report: $cmd"
        }
    }

    $implMatch = [regex]::Match($reviewText, '(?im)^\s*-\s*Implementation Agent:\s*(.+)\s*$')
    $revMatch  = [regex]::Match($reviewText, '(?im)^\s*-\s*Reviewer:\s*(.+)\s*$')
    if (-not $implMatch.Success -or -not $revMatch.Success) {
        Add-Issue -Severity "FAIL" -Check "independent-review" -Detail "Review report must include 'Implementation Agent' and 'Reviewer'."
    } else {
        $impl = $implMatch.Groups[1].Value.Trim()
        $rev  = $revMatch.Groups[1].Value.Trim()
        if ($impl.Equals($rev, [System.StringComparison]::OrdinalIgnoreCase)) {
            Add-Issue -Severity "FAIL" -Check "independent-review" -Detail "Reviewer must differ from implementation agent."
        } else {
            Add-Issue -Severity "PASS" -Check "independent-review" -Detail "Reviewer and implementation agent differ."
        }
    }
}

$handoffPath = Join-Path $RepoRoot $handoffPathRel
if (Test-Path -LiteralPath $handoffPath -PathType Leaf) {
    Add-Issue -Severity "PASS" -Check "handoff-artifact" -Detail "Handoff report found."
} else {
    Add-Issue -Severity "FAIL" -Check "handoff-artifact" -Detail "Required handoff report not found: $handoffPathRel"
}

Write-Host ""
Write-Host "Cycle-proof validation report"
Write-Host "Repo: $RepoRoot"
Write-Host "Contract: $ContractFile"
Write-Host ""
$issues | Format-Table -AutoSize Severity, Check, Detail
Write-Host ""
Write-Host ("Summary: PASS={0} WARN={1} FAIL={2}" -f $passCount, $warnCount, $failCount)

if ($failCount -gt 0) {
    exit 1
}
exit 0
