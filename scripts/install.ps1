param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [ValidateSet("ask", "replace", "merge", "keep")]
    [string]$ConflictAction = "ask",
    [string[]]$Category = @(),
    [switch]$DryRun,
    [switch]$InstallDeps,   # opt-in: auto-install via winget (off by default)
    [switch]$NoDeps,        # kept for compatibility; same as default
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$HomeDir = [Environment]::GetFolderPath("UserProfile")
$ManifestPath = Join-Path $RepoRoot "deploy/manifest.txt"
$TimeStamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupScriptPath = Join-Path $PSScriptRoot "backup-user-config.ps1"

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
    if ([string]::IsNullOrWhiteSpace($parent)) {
        return
    }
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
        } catch {
            # Non-zero code is expected if files differ.
        }
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
    if (Test-Path -LiteralPath $Target) {
        $existingText = Get-Content -LiteralPath $Target -Raw
    }
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
        if ($linked) {
            return $linked.FullName
        }
    } catch {
        return $null
    }
    return $null
}

function New-Link([string]$Source, [string]$Target) {
    Ensure-ParentDir $Target
    $sourceAbs = Get-AbsPath $Source

    if ($DryRun) {
        Write-Host "[DRY] Link: $Target -> $sourceAbs"
        return
    }

    if (Test-Path -LiteralPath $Target) {
        Remove-Item -LiteralPath $Target -Force -Recurse
    }

    try {
        New-Item -ItemType SymbolicLink -Path $Target -Target $sourceAbs -Force | Out-Null
        return
    } catch {
        if (Test-Path -LiteralPath $Source -PathType Leaf) {
            try {
                New-Item -ItemType HardLink -Path $Target -Target $sourceAbs -Force | Out-Null
                return
            } catch {
                throw "Unable to create file link for $Target -> $sourceAbs. Enable Developer Mode or run elevated."
            }
        }
        try {
            New-Item -ItemType Junction -Path $Target -Target $sourceAbs -Force | Out-Null
            return
        } catch {
            throw "Unable to create directory link for $Target -> $sourceAbs. Enable Developer Mode or run elevated."
        }
    }
}

function Select-Action([string]$Source, [string]$Target) {
    if ($ConflictAction -ne "ask") {
        return $ConflictAction
    }
    # Fall back to keep when not interactive
    if ($NonInteractive -or -not [System.Environment]::UserInteractive) {
        return "keep"
    }

    Show-Diff -Source $Source -Target $Target
    Write-Host ""
    Write-Host "Target exists: $Target"
    Write-Host "[R]eplace with link to repo"
    Write-Host "[M]erge into local file (conflict markers, no link)"
    Write-Host "[K]eep local file (no link)"
    while ($true) {
        try {
            $choice = (Read-Host "Choose action [R/M/K]").Trim().ToLowerInvariant()
        } catch {
            # Read-Host failed (non-interactive host) — keep local
            return "keep"
        }
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
        "keep" {
            Write-Host "[=] Keep local: $TargetFile"
        }
        default {
            throw "Unsupported action: $action"
        }
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
            if ($trimmed -match "@category\s+(\S+)") {
                $currentCategory = $Matches[1].Trim()
            }
            continue
        }

        # Filter by category if requested
        if ($Category.Count -gt 0 -and $currentCategory -notin $Category) {
            continue
        }

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
    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        return $true
    }
    if (-not $InstallDeps) {
        Write-Warn "$CommandName not found — skipping (pass -InstallDeps to auto-install via winget)."
        return $false
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warn "$CommandName missing and winget is unavailable. Install $CommandName manually."
        return $false
    }

    Invoke-Exec { winget install --id $WingetId -e --source winget --accept-package-agreements --accept-source-agreements } "Install dependency via winget: $WingetId"
    return [bool](Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Ensure-GitConfig([string]$HomePath) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        return
    }

    $name = (& git config --global --get user.name) 2>$null
    $email = (& git config --global --get user.email) 2>$null

    if (-not $name) {
        if ($NonInteractive) {
            Write-Warn "git user.name not configured. Set it manually."
        } else {
            $newName = Read-Host "git user.name is empty. Enter your name (or leave empty to skip)"
            if ($newName) {
                Invoke-Exec { git config --global user.name $newName } "Set git user.name"
            }
        }
    }

    if (-not $email) {
        if ($NonInteractive) {
            Write-Warn "git user.email not configured. Set it manually."
        } else {
            $newEmail = Read-Host "git user.email is empty. Enter your email (or leave empty to skip)"
            if ($newEmail) {
                Invoke-Exec { git config --global user.email $newEmail } "Set git user.email"
            }
        }
    }

    $excludesPath = Join-Path $HomePath ".gitignore_global"
    $hooksPath = Join-Path $HomePath ".githooks"
    Invoke-Exec { git config --global core.excludesfile $excludesPath } "Set git core.excludesfile -> $excludesPath"
    Invoke-Exec { git config --global core.hooksPath $hooksPath } "Set git core.hooksPath -> $hooksPath"
}

function Invoke-AutoBackup {
    if (-not (Test-Path -LiteralPath $BackupScriptPath -PathType Leaf)) {
        throw "Backup script not found: $BackupScriptPath"
    }

    Write-Step "Creating automatic pre-install backup"
    if ($DryRun) {
        & $BackupScriptPath -RepoRoot $RepoRoot -BackupName "install-$TimeStamp" -DryRun
    } else {
        & $BackupScriptPath -RepoRoot $RepoRoot -BackupName "install-$TimeStamp"
    }
}

Write-Step "Repo root: $RepoRoot"
if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Manifest not found: $ManifestPath"
}

Invoke-AutoBackup

Write-Step "Checking dependencies"
$gitOk = Ensure-Dependency -CommandName "git" -WingetId "Git.Git"
[void](Ensure-Dependency -CommandName "gitleaks" -WingetId "Gitleaks.Gitleaks")

$entries = Parse-Manifest -Path $ManifestPath
Write-Step "Manifest entries: $($entries.Count)"

foreach ($entry in $entries) {
    Deploy-Entry -SourceRel $entry.Source -TargetRel $entry.Target
}

function Ensure-CommitPolicy {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return }
    $marker = Join-Path $RepoRoot ".ai-agent-config-repo"
    if (Test-Path -LiteralPath $marker -PathType Leaf) {
        Invoke-Exec { git config ai-agent.allow-config-commits true } "Marking repo as canonical AI config repo (allows AI file commits)"
    }
}

function Ensure-CodexLocalTrust {
    # Set trust_repository = true in the local config if not present
    $localConfig = Join-Path $RepoRoot ".codex/config.toml"
    if (Test-Path -LiteralPath $localConfig -PathType Leaf) {
        $content = Get-Content -LiteralPath $localConfig -Raw
        if ($content -notmatch "trust_repository\s*=\s*true") {
            Invoke-Exec { Add-Content $localConfig "`ntrust_repository = true" } "Trusting repository in local Codex config"
        }
    }
}

function Ensure-CodexGlobalTrust {
    $globalConfig = Join-Path $HomeDir ".codex/config.toml"
    # Codex canonicalizes paths with \\?\ prefix on Windows
    $rawPath = (Resolve-Path -LiteralPath $RepoRoot).Path
    if (-not $rawPath.StartsWith("\\?\")) {
        $rawPath = "\\?\$rawPath"
    }
    $tomlHeader = "[projects.'$rawPath']"
    $trustLine = 'trust_level = "trusted"'

    if (-not (Test-Path -LiteralPath $globalConfig)) {
        Ensure-ParentDir $globalConfig
        Invoke-Exec { Set-Content $globalConfig "$tomlHeader`n$trustLine`n" } "Initialize Codex global trust"
        return
    }

    $content = Get-Content -LiteralPath $globalConfig -Raw
    if ($content -notmatch [regex]::Escape($rawPath)) {
        Invoke-Exec { Add-Content $globalConfig "`n$tomlHeader`n$trustLine`n" } "Add project to Codex global projects trust"
    }
}

if ($gitOk) {
    Ensure-GitConfig -HomePath $HomeDir
    Ensure-CommitPolicy
    Ensure-CodexLocalTrust
    Ensure-CodexGlobalTrust
}

Write-Step "Done."
