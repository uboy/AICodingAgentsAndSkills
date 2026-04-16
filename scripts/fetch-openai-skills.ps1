<#
.SYNOPSIS
    Fetches and distributes skills from the OpenAI Skills repository.
    
    Repo: https://github.com/openai/skills
#>

param(
    [string]$TargetDir = "skills",
    [string]$RepoUrl = "https://github.com/openai/skills",
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$TempDir = Join-Path $env:TEMP "openai-skills-$(Get-Random)"

try {
    Write-Host "--- OpenAI Skills Fetcher ---" -ForegroundColor Cyan
    
    # 1. Fetch
    if ($DryRun) {
        Write-Host "[DRY-RUN] Would clone $RepoUrl to temporary directory." -ForegroundColor Yellow
    } else {
        Write-Host "Cloning $RepoUrl..."
        git clone --depth 1 $RepoUrl $TempDir
    }

    # 2. Process Skills
    $skillsSource = Join-Path $TempDir "*"
    if ($DryRun) {
        $skillFolders = Get-ChildItem -Path $TempDir -Directory
    } else {
        $skillFolders = Get-ChildItem -Path $TempDir -Directory
    }

    foreach ($folder in $skillFolders) {
        $skillName = $folder.Name
        if ($skillName.StartsWith(".")) { continue }
        
        $destPath = Join-Path $RepoRoot $TargetDir $skillName
        $manifestPath = Join-Path $folder.FullName "SKILL.md"

        if (-not (Test-Path $manifestPath)) {
            Write-Host "Skipping ${skillName}: No SKILL.md found." -ForegroundColor Gray
            continue
        }

        if (Test-Path $destPath) {
            if ($Force) {
                Write-Host "Overwriting existing skill: ${skillName}" -ForegroundColor Yellow
            } else {
                Write-Host "Skill already exists, skipping: ${skillName} (use -Force to overwrite)" -ForegroundColor Gray
                continue
            }
        }

        if ($DryRun) {
            Write-Host "[DRY-RUN] Would copy skill: ${skillName} to $TargetDir/$skillName" -ForegroundColor Yellow
        } else {
            Write-Host "Installing skill: ${skillName}" -ForegroundColor Green
            Copy-Item -Path $folder.FullName -Destination $destPath -Recurse -Force
        }
    }

    Write-Host "`nDistribution complete." -ForegroundColor Cyan

} catch {
    Write-Error "Failed to fetch OpenAI skills: $_"
} finally {
    if (Test-Path $TempDir) {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
