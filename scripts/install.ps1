param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$HomeDir = "",
    [ValidateSet("ask", "replace", "merge", "keep")]
    [string]$ConflictAction = "ask",
    [string[]]$Category = @(),
    [switch]$DryRun,
    [switch]$InstallDeps,
    [switch]$NoDeps,
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ManifestPath = Join-Path $RepoRoot "deploy/manifest.txt"
$TimeStamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupScriptPath = Join-Path $PSScriptRoot "backup-user-config.ps1"

function Resolve-HomeDir([string]$OverrideHome) {
    if (-not [string]::IsNullOrWhiteSpace($OverrideHome)) {
        return $OverrideHome
    }
    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:HOME)) { $candidates += $env:HOME }
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) { $candidates += $env:USERPROFILE }
    $profileHome = [Environment]::GetFolderPath("UserProfile")
    if (-not [string]::IsNullOrWhiteSpace($profileHome)) { $candidates += $profileHome }

    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw "Unable to resolve home directory. Pass -HomeDir explicitly."
}

$HomeDir = Resolve-HomeDir -OverrideHome $HomeDir

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

function Get-AbsPath([string]$Path) {
    return (Resolve-Path -LiteralPath $Path).Path
}

function Ensure-ParentDir([string]$Path) {
    $parent = Split-Path -Parent $Path
    if ([string]::IsNullOrWhiteSpace($parent)) { return }
    if (-not (Test-Path -LiteralPath $parent)) {
        Invoke-Exec { New-Item -ItemType Directory -Path $parent -Force | Out-Null } "Create directory: $parent"
    }
}

function Backup-Existing([string]$Path) {
    $backup = "$Path.backup-$TimeStamp"
    Invoke-Exec { Copy-Item -LiteralPath $Path -Destination $backup -Recurse -Force } "Backup: $Path -> $backup"
    return $backup
}

function Show-Diff([string]$Source, [string]$Target) {
    Write-Host ""
    Write-Host "--- DIFF: $Target <-> $Source"
    if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $Target)) {
        try {
            & git --no-pager diff --no-index -- $Target $Source | Out-Host
            return
        } catch { }
    }
    $left = Get-Content -LiteralPath $Target -ErrorAction SilentlyContinue
    $right = Get-Content -LiteralPath $Source -ErrorAction SilentlyContinue
    Compare-Object -ReferenceObject $left -DifferenceObject $right -IncludeEqual:$false |
        Select-Object -First 200 |
        ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" } |
        Out-Host
}

function Write-MergedConflictFile([string]$Source, [string]$Target) {
    $existingText = ""
    if (Test-Path -LiteralPath $Target) { $existingText = Get-Content -LiteralPath $Target -Raw }
    $sourceText = Get-Content -LiteralPath $Source -Raw
    $merged = @(
        "<<<<<<< LOCAL ($Target)"
        $existingText
        "======="
        $sourceText
        ">>>>>>> REPOSITORY ($Source)"
    ) -join "`n"
    Invoke-Exec { Set-Content -LiteralPath $Target -Value $merged -NoNewline } "Write merged conflict file: $Target"
}

function Resolve-LinkTarget([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $null }
    if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $null }
    try {
        $linked = $item.ResolveLinkTarget($true)
        if ($linked) { return $linked.FullName }
    } catch { return $null }
    return $null
}

function New-Link([string]$Source, [string]$Target) {
    Ensure-ParentDir $Target
    $sourceAbs = Get-AbsPath $Source
    if ($DryRun) {
        Write-Host "[DRY] Link: $Target -> $sourceAbs"
        return
    }
    if (Test-Path -LiteralPath $Target) { Remove-Item -LiteralPath $Target -Force -Recurse }
    try {
        New-Item -ItemType SymbolicLink -Path $Target -Target $sourceAbs -Force | Out-Null
    } catch {
        if (Test-Path -LiteralPath $Source -PathType Leaf) {
            try {
                New-Item -ItemType HardLink -Path $Target -Target $sourceAbs -Force | Out-Null
            } catch {
                throw "Unable to create hard link for $Target -> $sourceAbs."
            }
        } else {
            try {
                New-Item -ItemType Junction -Path $Target -Target $sourceAbs -Force | Out-Null
            } catch {
                throw "Unable to create junction for $Target -> $sourceAbs."
            }
        }
    }
}

function Select-Action([string]$Source, [string]$Target) {
    if ($ConflictAction -ne "ask") { return $ConflictAction }
    if ($NonInteractive -or -not [System.Environment]::UserInteractive) { return "keep" }
    Show-Diff -Source $Source -Target $Target
    Write-Host ""
    Write-Host "Target exists: $Target"
    Write-Host "[R]eplace with link to repo"
    Write-Host "[M]erge into local file (conflict markers, no link)"
    Write-Host "[K]eep local file (no link)"
    while ($true) {
        try {
            $choice = (Read-Host "Choose action [R/M/K]").Trim().ToLowerInvariant()
        } catch { return "keep" }
        switch ($choice) {
            "r" { return "replace" }
            "m" { return "merge" }
            "k" { return "keep" }
            default { Write-Warn "Invalid choice. Enter R, M, or K." }
        }
    }
}

function Deploy-File([string]$SourceFile, [string]$TargetFile) {
    if (-not (Test-Path -LiteralPath $SourceFile -PathType Leaf)) {
        Write-Warn "Skip missing source file: $SourceFile"
        return
    }
    if (-not (Test-Path -LiteralPath $TargetFile)) {
        New-Link -Source $SourceFile -Target $TargetFile
        return
    }
    $sourceAbs = Get-AbsPath $SourceFile
    $linkedTarget = Resolve-LinkTarget -Path $TargetFile
    if ($linkedTarget -and ((Get-AbsPath $linkedTarget) -eq $sourceAbs)) {
        Write-Host "[=] Already linked: $TargetFile"
        return
    }
    $action = Select-Action -Source $SourceFile -Target $TargetFile
    switch ($action) {
        "replace" {
            [void](Backup-Existing -Path $TargetFile)
            New-Link -Source $SourceFile -Target $TargetFile
        }
        "merge" {
            [void](Backup-Existing -Path $TargetFile)
            Write-MergedConflictFile -Source $SourceFile -Target $TargetFile
        }
        "keep" { Write-Host "[=] Keep local: $TargetFile" }
        default { throw "Unsupported action: $action" }
    }
}

function Deploy-Entry([string]$SourceRel, [string]$TargetRel) {
    $sourcePath = Join-Path $RepoRoot $SourceRel
    $targetPath = Join-Path $HomeDir $TargetRel
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        Write-Warn "Skip (source missing): $SourceRel"
        return
    }
    if (Test-Path -LiteralPath $sourcePath -PathType Container) {
        Write-Step "Deploy directory: $SourceRel -> $TargetRel"
        Get-ChildItem -LiteralPath $sourcePath -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($sourcePath.Length).TrimStart('\', '/')
            $dst = Join-Path $targetPath $rel
            Deploy-File -SourceFile $_.FullName -TargetFile $dst
        }
    } else {
        Write-Step "Deploy file: $SourceRel -> $TargetRel"
        Deploy-File -SourceFile $sourcePath -TargetFile $targetPath
    }
}

function Parse-Manifest([string]$Path) {
    $items = @()
    $currentCategory = "default"
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed.StartsWith("#")) {
            if ($trimmed -match "@category\s+(\S+)") { $currentCategory = $Matches[1].Trim() }
            continue
        }
        if ($Category.Count -gt 0 -and $currentCategory -notin $Category) { continue }
        $parts = $trimmed.Split("|", 2)
        if ($parts.Count -ne 2) {
            Write-Warn "Invalid manifest line: $line"
            continue
        }
        $items += [PSCustomObject]@{
            Source = $parts[0].Trim()
            Target = $parts[1].Trim()
            Category = $currentCategory
        }
    }
    return $items
}

function Ensure-Dependency([string]$CommandName, [string]$WingetId) {
    if (Get-Command $CommandName -ErrorAction SilentlyContinue) { return $true }
    if (-not $InstallDeps) {
        Write-Warn "$CommandName not found  skipping (pass -InstallDeps to auto-install via winget)."
        return $false
    }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warn "$CommandName missing and winget is unavailable."
        return $false
    }
    Invoke-Exec { winget install --id $WingetId -e --source winget --accept-package-agreements --accept-source-agreements } "Install dependency: $WingetId"
    return [bool](Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Ensure-GitConfig([string]$HomePath) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return }
    $excludesPath = Join-Path $HomePath ".gitignore_global"
    $hooksPath = Join-Path $HomePath ".githooks"
    Invoke-Exec { git config --global core.excludesfile $excludesPath } "Set git core.excludesfile -> $excludesPath"
    Invoke-Exec { git config --global core.hooksPath $hooksPath } "Set git core.hooksPath -> $hooksPath"
}

function Invoke-AutoBackup {
    if (-not (Test-Path -LiteralPath $BackupScriptPath -PathType Leaf)) { throw "Backup script not found: $BackupScriptPath" }
    Write-Step "Creating automatic pre-install backup"
    $backupParams = @{
        RepoRoot = $RepoRoot
        HomeDir = $HomeDir
        BackupName = "install-$TimeStamp"
    }
    if ($DryRun) { $backupParams["DryRun"] = $true }
    & $BackupScriptPath @backupParams
}

Write-Step "Repo root: $RepoRoot"
if (-not (Test-Path -LiteralPath $ManifestPath)) { throw "Manifest not found: $ManifestPath" }

Invoke-AutoBackup

Write-Step "Checking dependencies"
$gitOk = Ensure-Dependency -CommandName "git" -WingetId "Git.Git"
[void](Ensure-Dependency -CommandName "gitleaks" -WingetId "Gitleaks.Gitleaks")

$entries = @(Parse-Manifest -Path $ManifestPath)
Write-Step "Manifest entries: $($entries.Count)"

foreach ($entry in $entries) {
    Deploy-Entry -SourceRel $entry.Source -TargetRel $entry.Target
}

if ($gitOk) {
    Ensure-GitConfig -HomePath $HomeDir
}

Write-Host "[*] Done."
