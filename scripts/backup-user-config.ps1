param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$HomeDir = "",
    [string]$BackupRoot = "",
    [string]$BackupName = "",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ManifestPath = Join-Path $RepoRoot "deploy/manifest.txt"

function Resolve-HomeDir([string]$OverrideHome) {
    if (-not [string]::IsNullOrWhiteSpace($OverrideHome)) {
        return $OverrideHome
    }

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:HOME)) {
        $candidates += $env:HOME
    }
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        $candidates += $env:USERPROFILE
    }
    $profileHome = [Environment]::GetFolderPath("UserProfile")
    if (-not [string]::IsNullOrWhiteSpace($profileHome)) {
        $candidates += $profileHome
    }

    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Unable to resolve home directory. Pass -HomeDir explicitly."
}

$HomeDir = Resolve-HomeDir -OverrideHome $HomeDir

if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
    $BackupRoot = Join-Path $HomeDir ".ai-agent-config-backups"
}
if ([string]::IsNullOrWhiteSpace($BackupName)) {
    $BackupName = Get-Date -Format "yyyyMMdd-HHmmss"
}

$BackupDir = Join-Path $BackupRoot $BackupName
$BackupFilesDir = Join-Path $BackupDir "files"
$IndexPath = Join-Path $BackupDir "index.tsv"

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

function Parse-Manifest([string]$Path) {
    $items = @()
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            continue
        }
        $parts = $trimmed.Split("|", 2)
        if ($parts.Count -ne 2) {
            continue
        }
        $items += [PSCustomObject]@{
            Source = $parts[0].Trim()
            Target = $parts[1].Trim()
        }
    }
    return $items
}

function Ensure-Parent([string]$Path) {
    $parent = Split-Path -Parent $Path
    if ([string]::IsNullOrWhiteSpace($parent)) {
        return
    }
    if (-not (Test-Path -LiteralPath $parent)) {
        Invoke-Exec { New-Item -ItemType Directory -Path $parent -Force | Out-Null } "Create directory: $parent"
    }
}

function Resolve-LinkTarget([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $null }
    if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $null }
    try {
        $linked = $item.ResolveLinkTarget($true)
        if ($linked) { return $linked.FullName }
    } catch {
        return $null
    }
    return $null
}

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Manifest not found: $ManifestPath"
}

$entries = Parse-Manifest -Path $ManifestPath
$indexRows = New-Object System.Collections.Generic.List[object]
$seenTargets = @{}

Write-Step "Repo root: $RepoRoot"
Write-Step "Home dir: $HomeDir"
Write-Step "Backup dir: $BackupDir"

Invoke-Exec { New-Item -ItemType Directory -Path $BackupFilesDir -Force | Out-Null } "Create backup directory: $BackupFilesDir"

foreach ($entry in $entries) {
    $targetRel = $entry.Target
    if ($seenTargets.ContainsKey($targetRel)) {
        continue
    }
    $seenTargets[$targetRel] = $true

    $targetPath = Join-Path $HomeDir $targetRel
    $backupPath = Join-Path $BackupFilesDir $targetRel

    if (-not (Test-Path -LiteralPath $targetPath)) {
        $indexRows.Add([PSCustomObject]@{
            Status = "MISSING"
            Target = $targetRel
            SourcePath = $targetPath
            BackupPath = ""
            Notes = "Target does not exist in home."
        })
        continue
    }

    $linked = Resolve-LinkTarget -Path $targetPath
    if ($linked) {
        $repoFull = (Resolve-Path -LiteralPath $RepoRoot).Path
        if ($linked.StartsWith($repoFull, [System.StringComparison]::OrdinalIgnoreCase)) {
            $indexRows.Add([PSCustomObject]@{
                Status = "SKIP_LINKED_TO_REPO"
                Target = $targetRel
                SourcePath = $targetPath
                BackupPath = ""
                Notes = "Target is linked to repo source."
            })
            continue
        }
    }

    Ensure-Parent -Path $backupPath
    Invoke-Exec { Copy-Item -LiteralPath $targetPath -Destination $backupPath -Recurse -Force } "Backup: $targetPath -> $backupPath"

    $indexRows.Add([PSCustomObject]@{
        Status = "BACKED_UP"
        Target = $targetRel
        SourcePath = $targetPath
        BackupPath = $backupPath
        Notes = ""
    })
}

if (-not $DryRun) {
    $lines = @("status`ttarget`tsource_path`tbackup_path`tnotes")
    foreach ($row in $indexRows) {
        $lines += ("{0}`t{1}`t{2}`t{3}`t{4}" -f $row.Status, $row.Target, $row.SourcePath, $row.BackupPath, $row.Notes)
    }
    Set-Content -LiteralPath $IndexPath -Value ($lines -join "`n")
}

Write-Host ""
Write-Host "Backup summary:"
$indexRows | Group-Object Status | Sort-Object Name | ForEach-Object {
    Write-Host ("- {0}: {1}" -f $_.Name, $_.Count)
}

Write-Host ""
if ($DryRun) {
    Write-Host "Dry-run finished. No files were copied."
} else {
    Write-Host "Backup created at: $BackupDir"
    Write-Host "Index file: $IndexPath"
}
