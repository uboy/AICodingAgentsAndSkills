param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SkillsRoot = Join-Path $RepoRoot "skills"
$EvalsRoot = Join-Path $RepoRoot "evals/skills/cases"

if (-not (Test-Path -LiteralPath $SkillsRoot -PathType Container)) {
    throw "Skills directory not found: $SkillsRoot"
}

$skillFiles = Get-ChildItem -LiteralPath $SkillsRoot -Recurse -File -Filter "SKILL.md" |
    Sort-Object FullName

if ($skillFiles.Count -eq 0) {
    throw "No SKILL.md files found under: $SkillsRoot"
}

$results = New-Object System.Collections.Generic.List[object]
$failCount = 0

function Add-Result([string]$SkillName, [string]$Status, [string]$Detail) {
    $results.Add([PSCustomObject]@{
        Skill  = $SkillName
        Status = $Status
        Detail = $Detail
    })
    if ($Status -eq "FAIL") {
        $script:failCount++
    }
}

foreach ($file in $skillFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $skillDir = Split-Path -Path $file.FullName -Parent
    $skillName = Split-Path -Path $skillDir -Leaf
    $problems = New-Object System.Collections.Generic.List[string]

    $frontmatterMatch = [regex]::Match($content, '(?s)\A---\r?\n(.*?)\r?\n---\r?\n')
    if (-not $frontmatterMatch.Success) {
        $problems.Add("Missing YAML frontmatter delimited by '---' at file start.")
    } else {
        $frontmatter = $frontmatterMatch.Groups[1].Value
        if ($frontmatter -notmatch "(?m)^name:\s*\S+") {
            $problems.Add("Frontmatter missing required 'name' field.")
        }
        if ($frontmatter -notmatch "(?m)^description:\s*\S+") {
            $problems.Add("Frontmatter missing required 'description' field.")
        }
    }

    if ($content -notmatch "(?m)^# Skill:\s+\S+") {
        $problems.Add("Missing top-level '# Skill: <name>' header.")
    }
    if ($content -notmatch "(?m)^## Purpose\s*$") {
        $problems.Add("Missing '## Purpose' section.")
    }
    if ($content -notmatch "(?m)^## Input\s*$") {
        $problems.Add("Missing '## Input' section.")
    }
    if ($content -notmatch "(?m)^## (Output Format|Mode Contracts)\s*$" -and $content -notmatch "(?m)^Output:\s*$") {
        $problems.Add("Missing output contract (expected '## Output Format', '## Mode Contracts', or 'Output:').")
    }
    if ($content -notmatch "(?m)^## (Shared Safety|Safety Rules|Global Safety Rules|Global Processing Rules)\s*$") {
        $problems.Add("Missing safety section.")
    }

    $requiresEval = -not $skillName.StartsWith("_")
    if ($requiresEval) {
        $evalCasePath = Join-Path $EvalsRoot ("{0}.md" -f $skillName)
        if (-not (Test-Path -LiteralPath $evalCasePath -PathType Leaf)) {
            $problems.Add("Missing eval case: $evalCasePath")
        }
    }

    if ($problems.Count -eq 0) {
        Add-Result -SkillName $skillName -Status "PASS" -Detail "Structure checks passed."
    } else {
        Add-Result -SkillName $skillName -Status "FAIL" -Detail ($problems -join " ")
    }
}

Write-Host ""
Write-Host "Skill validation report"
Write-Host "Repo: $RepoRoot"
Write-Host ""
$results | Format-Table -AutoSize Skill, Status, Detail

Write-Host ""
if ($failCount -gt 0) {
    Write-Host ("Validation failed: {0} skill(s) have issues." -f $failCount)
    exit 1
}
Write-Host "Validation passed."
