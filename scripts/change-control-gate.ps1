param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$ScopeFile = "coordination/change-scope.txt",
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

function Test-AnyPattern([string]$RelPath, [string[]]$Patterns) {
    foreach ($pattern in $Patterns) {
        if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
        if ($RelPath -like $pattern) { return $true }
    }
    return $false
}

function ConvertTo-HashtableRecursive([object]$InputObject) {
    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $table = @{}
        foreach ($key in $InputObject.Keys) {
            $table["$key"] = ConvertTo-HashtableRecursive -InputObject $InputObject[$key]
        }
        return $table
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        $items = @()
        foreach ($item in $InputObject) {
            $items += ,(ConvertTo-HashtableRecursive -InputObject $item)
        }
        return $items
    }

    if ($InputObject -is [pscustomobject]) {
        $table = @{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $table[$prop.Name] = ConvertTo-HashtableRecursive -InputObject $prop.Value
        }
        return $table
    }

    return $InputObject
}

function ConvertFrom-JsonHashtableCompat([string]$JsonText) {
    $jsonCmd = Get-Command ConvertFrom-Json -ErrorAction Stop
    $supportsAsHashtable = $false
    foreach ($p in $jsonCmd.Parameters.Keys) {
        if ($p -eq "AsHashtable") {
            $supportsAsHashtable = $true
            break
        }
    }

    if ($supportsAsHashtable) {
        return ($JsonText | ConvertFrom-Json -AsHashtable)
    }

    $obj = $JsonText | ConvertFrom-Json
    return ConvertTo-HashtableRecursive -InputObject $obj
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

$headCheck = Git-Out -GitArgs @("rev-parse", "--verify", "HEAD")
if ($headCheck.ExitCode -eq 0) {
    $diffA = Git-Out -GitArgs @("diff", "--name-only", "--diff-filter=ACMRTUXB", "HEAD")
    $diffB = Git-Out -GitArgs @("diff", "--cached", "--name-only", "--diff-filter=ACMRTUXB")
    $diffC = Git-Out -GitArgs @("ls-files", "--others", "--exclude-standard")
} else {
    $diffA = Git-Out -GitArgs @("ls-files", "--others", "--modified", "--exclude-standard")
    $diffB = Git-Out -GitArgs @("diff", "--cached", "--name-only", "--diff-filter=ACMRTUXB")
    $diffC = [PSCustomObject]@{ ExitCode = 0; Lines = @() }
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

if ($changed.Count -eq 0) {
    Add-Issue -Severity "WARN" -Check "changed-files" -Detail "No changed files detected against HEAD."
}

$scopePath = Join-Path $RepoRoot $ScopeFile
$scopeRel = Normalize-RelPath $ScopeFile
$approvalPath = Join-Path $RepoRoot $ApprovalFile
$approvalRel = Normalize-RelPath $ApprovalFile
$scopePatterns = New-Object System.Collections.Generic.List[string]
if (-not (Test-Path -LiteralPath $scopePath -PathType Leaf)) {
    Add-Issue -Severity "FAIL" -Check "scope-file" -Detail ("Missing scope file: {0}. Create it from coordination/templates/change-scope.txt." -f $scopeRel)
} else {
    foreach ($line in Get-Content -LiteralPath $scopePath) {
        $trimmed = "$line".Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed.StartsWith("#")) { continue }
        $scopePatterns.Add((Normalize-RelPath $trimmed))
    }
    if ($scopePatterns.Count -eq 0) {
        Add-Issue -Severity "FAIL" -Check "scope-file" -Detail ("Scope file is empty: {0}" -f $scopeRel)
    } else {
        Add-Issue -Severity "PASS" -Check "scope-file" -Detail ("Loaded {0} scope pattern(s) from {1}" -f $scopePatterns.Count, $scopeRel)
    }
}

$alwaysAllowed = @(
    $scopeRel,
    $approvalRel,
    "coordination/tasks.jsonl",
    "coordination/state/*",
    "coordination/handoffs/*",
    "coordination/reviews/*",
    "coordination/templates/approval-overrides.json",
    ".scratchpad/*",
    ".agent-memory/*"
)

$outOfScope = New-Object System.Collections.Generic.List[string]
if ($scopePatterns.Count -gt 0 -and $changed.Count -gt 0) {
    foreach ($rel in $changed) {
        if (Test-AnyPattern -RelPath $rel -Patterns $alwaysAllowed) { continue }
        if (Test-AnyPattern -RelPath $rel -Patterns $scopePatterns) { continue }
        $outOfScope.Add($rel)
    }
}
if ($outOfScope.Count -gt 0) {
    Add-Issue -Severity "FAIL" -Check "scope-drift" -Detail ("Out-of-scope changes: {0}" -f ($outOfScope -join ", "))
} elseif ($changed.Count -gt 0 -and $scopePatterns.Count -gt 0) {
    Add-Issue -Severity "PASS" -Check "scope-drift" -Detail "All changed files are within declared scope."
}

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
    "templates/git/pre-commit"
)

$functionalChanged = @(
    $changed | Where-Object {
        (Test-AnyPattern -RelPath $_ -Patterns $functionalPatterns) -and
        (-not (Test-AnyPattern -RelPath $_ -Patterns $alwaysAllowed))
    }
)

$trivialConfigPatterns = @(
    ".claude/settings.json",
    ".gemini/settings.json",
    "configs/codex/config.toml",
    "opencode.json",
    ".cursorrules",
    ".cursor/rules/*",
    ".agent-memory/*",
    "README.md"
)
$trivialSupportPatterns = @(
    "coordination/*",
    ".scratchpad/*"
)

$isTrivialConfigOnly = $false
if ($changed.Count -gt 0) {
    $hasNonTrivial = @(
        $changed | Where-Object {
            (-not (Test-AnyPattern -RelPath $_ -Patterns $alwaysAllowed)) -and
            (-not (Test-AnyPattern -RelPath $_ -Patterns $trivialConfigPatterns)) -and
            (-not (Test-AnyPattern -RelPath $_ -Patterns $trivialSupportPatterns))
        }
    ).Count -gt 0

    $hasTrivialConfig = @(
        $changed | Where-Object { Test-AnyPattern -RelPath $_ -Patterns $trivialConfigPatterns }
    ).Count -gt 0

    if ((-not $hasNonTrivial) -and $hasTrivialConfig) {
        $isTrivialConfigOnly = $true
    }
}

if ($functionalChanged.Count -gt 0 -and (-not $isTrivialConfigOnly)) {
    $docsPatterns = @(
        "README.md",
        "policy/*.md",
        "coordination/PLAN-TASK-PROTOCOL.md",
        "coordination/templates/*",
        "docs/*",
        "SPEC.md"
    )
    $hasDocsEvidence = @($changed | Where-Object { Test-AnyPattern -RelPath $_ -Patterns $docsPatterns }).Count -gt 0
    $hasTaskUpdate = $changed -contains "coordination/tasks.jsonl"
    $hasHandoffInChanges = @($changed | Where-Object { $_ -like "coordination/handoffs/*.md" }).Count -gt 0
    $handoffDir = Join-Path $RepoRoot "coordination/handoffs"
    $hasHandoffFile = (Test-Path -LiteralPath $handoffDir -PathType Container) -and
        (@(Get-ChildItem -LiteralPath $handoffDir -File -Filter "*.md" | Where-Object { $_.Name -ne ".gitkeep" }).Count -gt 0)
    $hasHandoff = $hasHandoffInChanges -or $hasHandoffFile
    $reviewFiles = @($changed | Where-Object { $_ -like "coordination/reviews/*.md" -and $_ -ne "coordination/reviews/.gitkeep" })
    $hasReviewReport = $reviewFiles.Count -gt 0

    if (-not $hasDocsEvidence) {
        Add-Issue -Severity "FAIL" -Check "docs-contract" -Detail "Functional changes detected without docs/policy update."
    } else {
        Add-Issue -Severity "PASS" -Check "docs-contract" -Detail "Functional changes include docs/policy updates."
    }
    if (-not $hasTaskUpdate) {
        Add-Issue -Severity "FAIL" -Check "tasks-checklist" -Detail "Functional changes detected without coordination/tasks.jsonl update."
    } else {
        Add-Issue -Severity "PASS" -Check "tasks-checklist" -Detail "coordination/tasks.jsonl updated."
    }
    if (-not $hasHandoff) {
        Add-Issue -Severity "FAIL" -Check "handoff-evidence" -Detail "Functional changes detected without coordination/handoffs/*.md update."
    } else {
        Add-Issue -Severity "PASS" -Check "handoff-evidence" -Detail "Handoff evidence detected."
    }
    if (-not $hasReviewReport) {
        Add-Issue -Severity "FAIL" -Check "review-pipeline" -Detail "Functional changes detected without coordination/reviews/*.md report."
    } else {
        $validateReviewScript = Join-Path $RepoRoot "scripts/validate-review-report.ps1"
        if (Test-Path -LiteralPath $validateReviewScript -PathType Leaf) {
            & $validateReviewScript -RepoRoot $RepoRoot -FilesToValidate $reviewFiles
            if ($LASTEXITCODE -ne 0) {
                Add-Issue -Severity "FAIL" -Check "review-pipeline" -Detail "Review report validation failed."
            } else {
                Add-Issue -Severity "PASS" -Check "review-pipeline" -Detail "Review report present and valid."
            }
        } else {
            Add-Issue -Severity "FAIL" -Check "review-pipeline" -Detail "scripts/validate-review-report.ps1 not found."
        }
    }

    $significantLogicPatterns = @(
        "scripts/change-control-gate.*",
        "scripts/security-review-gate.*",
        "scripts/validate-*.ps1",
        "scripts/validate-*.sh",
        "scripts/install.*",
        "scripts/run-integrity-fast.*",
        "policy/*.md",
        "policy/*.json",
        "AGENTS*.md",
        "configs/codex/config.toml",
        "deploy/manifest.txt"
    )
    $hasSignificantLogicChange = @(
        $changed | Where-Object { Test-AnyPattern -RelPath $_ -Patterns $significantLogicPatterns }
    ).Count -gt 0
    $hasReadmeUpdate = $changed -contains "README.md"

    if ($hasSignificantLogicChange) {
        if ($hasReadmeUpdate) {
            Add-Issue -Severity "PASS" -Check "significant-doc-sync" -Detail "Significant logic change includes README.md update."
        } else {
            Add-Issue -Severity "FAIL" -Check "significant-doc-sync" -Detail "Significant logic change requires README.md update (requirements/behavior/capabilities documentation)."
        }
    } else {
        Add-Issue -Severity "PASS" -Check "significant-doc-sync" -Detail "No significant logic changes requiring mandatory README sync."
    }
} else {
    if ($isTrivialConfigOnly) {
        Add-Issue -Severity "PASS" -Check "docs-contract" -Detail "Trivial config-only change: full docs/checklist/review contract not required."
        Add-Issue -Severity "PASS" -Check "tasks-checklist" -Detail "Trivial config-only change: tasks checklist update optional."
        Add-Issue -Severity "PASS" -Check "handoff-evidence" -Detail "Trivial config-only change: handoff update optional."
        Add-Issue -Severity "PASS" -Check "review-pipeline" -Detail "Trivial config-only change: review report optional."
    } else {
        Add-Issue -Severity "PASS" -Check "docs-contract" -Detail "No functional changes requiring docs/checklist/handoff contract."
    }
}

$approval = @{
    allow_existing_test_modifications = $false
    allow_architecture_changes = $false
    approved_by = ""
    reason = ""
}
if (Test-Path -LiteralPath $approvalPath -PathType Leaf) {
    try {
        $parsed = ConvertFrom-JsonHashtableCompat -JsonText (Get-Content -LiteralPath $approvalPath -Raw)
        if ($parsed.ContainsKey("allow_existing_test_modifications")) {
            $approval.allow_existing_test_modifications = [bool]$parsed.allow_existing_test_modifications
        }
        if ($parsed.ContainsKey("allow_architecture_changes")) {
            $approval.allow_architecture_changes = [bool]$parsed.allow_architecture_changes
        }
        if ($parsed.ContainsKey("approved_by")) {
            $approval.approved_by = "$($parsed.approved_by)"
        }
        if ($parsed.ContainsKey("reason")) {
            $approval.reason = "$($parsed.reason)"
        }
        Add-Issue -Severity "PASS" -Check "approval-file" -Detail ("Loaded override controls from {0}" -f $approvalRel)
    } catch {
        Add-Issue -Severity "FAIL" -Check "approval-file" -Detail ("Invalid JSON in {0}" -f $approvalRel)
    }
} else {
    Add-Issue -Severity "PASS" -Check "approval-file" -Detail ("No override file detected ({0}); strict defaults active." -f $approvalRel)
}

$statusOut = Git-Out -GitArgs @("status", "--porcelain")
$statusLines = @($statusOut.Lines | ForEach-Object { "$_" } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$testPatterns = @("tests/*", "evals/*", "*.test.ps1", "*.test.sh", "*.spec.*")
$archPatterns = @("docs/design/*", "docs/architecture/*", "ARCHITECTURE.md", "SPEC.md")
$existingTestsTouched = New-Object System.Collections.Generic.List[string]
$existingArchTouched = New-Object System.Collections.Generic.List[string]

foreach ($line in $statusLines) {
    if ($line.Length -lt 4) { continue }
    $xy = $line.Substring(0, 2)
    $pathPart = $line.Substring(3).Trim()
    if ($pathPart.Contains(" -> ")) {
        $parts = $pathPart.Split(" -> ")
        $pathPart = $parts[$parts.Count - 1]
    }
    $rel = Normalize-RelPath $pathPart
    if ([string]::IsNullOrWhiteSpace($rel)) { continue }

    $isNew = ($xy -eq "??") -or ($xy[0] -eq 'A') -or ($xy[1] -eq 'A')
    if ($isNew) { continue }

    if (Test-AnyPattern -RelPath $rel -Patterns $testPatterns) {
        $existingTestsTouched.Add($rel)
    }
    if (Test-AnyPattern -RelPath $rel -Patterns $archPatterns) {
        $existingArchTouched.Add($rel)
    }
}

$existingTestsTouched = @($existingTestsTouched | Select-Object -Unique)
$existingArchTouched = @($existingArchTouched | Select-Object -Unique)

if ($existingTestsTouched.Count -gt 0) {
    if ($approval.allow_existing_test_modifications) {
        Add-Issue -Severity "WARN" -Check "test-freeze" -Detail ("Existing tests modified with override approval ({0}): {1}" -f $approval.approved_by, ($existingTestsTouched -join ", "))
    } else {
        Add-Issue -Severity "FAIL" -Check "test-freeze" -Detail ("Existing tests modified without approval override: {0}" -f ($existingTestsTouched -join ", "))
    }
} else {
    Add-Issue -Severity "PASS" -Check "test-freeze" -Detail "No existing tests were modified."
}

if ($existingArchTouched.Count -gt 0) {
    if ($approval.allow_architecture_changes) {
        Add-Issue -Severity "WARN" -Check "arch-freeze" -Detail ("Architecture/design files modified with override approval ({0}): {1}" -f $approval.approved_by, ($existingArchTouched -join ", "))
    } else {
        Add-Issue -Severity "FAIL" -Check "arch-freeze" -Detail ("Architecture/design files modified without approval override: {0}" -f ($existingArchTouched -join ", "))
    }
} else {
    Add-Issue -Severity "PASS" -Check "arch-freeze" -Detail "No existing architecture/design files were modified."
}

Write-Host ""
Write-Host "Change-control gate report"
Write-Host "Repo: $RepoRoot"
Write-Host "Changed files: $($changed.Count)"
Write-Host "Scope file: $scopeRel"
Write-Host ""
$issues | Format-Table -AutoSize Severity, Check, Detail
Write-Host ""
Write-Host ("Summary: PASS={0} WARN={1} FAIL={2}" -f $passCount, $warnCount, $failCount)

if ($failCount -gt 0) {
    exit 1
}
exit 0
