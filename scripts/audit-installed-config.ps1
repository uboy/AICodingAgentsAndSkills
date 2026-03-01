param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$HomeDir = ""
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

function Get-Abs([string]$Path) {
    try {
        return (Resolve-Path -LiteralPath $Path).Path
    } catch {
        return $Path
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

function Test-SameContent([string]$A, [string]$B) {
    if (-not (Test-Path -LiteralPath $A -PathType Leaf)) { return $false }
    if (-not (Test-Path -LiteralPath $B -PathType Leaf)) { return $false }

    $aInfo = Get-Item -LiteralPath $A
    $bInfo = Get-Item -LiteralPath $B
    if ($aInfo.Length -ne $bInfo.Length) {
        return $false
    }

    try {
        $aHash = (Get-FileHash -LiteralPath $A -Algorithm SHA256).Hash
        $bHash = (Get-FileHash -LiteralPath $B -Algorithm SHA256).Hash
        return $aHash -eq $bHash
    } catch {
        return (Get-Content -LiteralPath $A -Raw) -eq (Get-Content -LiteralPath $B -Raw)
    }
}

$results = New-Object System.Collections.Generic.List[object]
$statusCount = @{}

function Add-Result([string]$Status, [string]$Kind, [string]$Source, [string]$Target, [string]$Detail) {
    $results.Add([PSCustomObject]@{
        Status = $Status
        Kind = $Kind
        Source = $Source
        Target = $Target
        Detail = $Detail
    })
    if (-not $statusCount.ContainsKey($Status)) {
        $statusCount[$Status] = 0
    }
    $statusCount[$Status]++
}

function Audit-File([string]$SourceFile, [string]$TargetFile, [string]$Kind) {
    if (-not (Test-Path -LiteralPath $SourceFile -PathType Leaf)) {
        Add-Result -Status "SOURCE-MISSING" -Kind $Kind -Source $SourceFile -Target $TargetFile -Detail "Source file not found in repo."
        return
    }

    if (-not (Test-Path -LiteralPath $TargetFile -PathType Leaf)) {
        Add-Result -Status "MISSING" -Kind $Kind -Source $SourceFile -Target $TargetFile -Detail "Target file not found in home."
        return
    }

    $linkedTarget = Resolve-LinkTarget -Path $TargetFile
    if ($linkedTarget) {
        if ((Get-Abs $linkedTarget) -eq (Get-Abs $SourceFile)) {
            Add-Result -Status "OK-LINKED" -Kind $Kind -Source $SourceFile -Target $TargetFile -Detail "Target points to repo source."
            return
        }
    }

    if (Test-SameContent -A $SourceFile -B $TargetFile) {
        Add-Result -Status "OK-EQUAL" -Kind $Kind -Source $SourceFile -Target $TargetFile -Detail "Content matches source."
        return
    }

    Add-Result -Status "DIFFERENT" -Kind $Kind -Source $SourceFile -Target $TargetFile -Detail "Content differs from source."
}

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Manifest not found: $ManifestPath"
}

$entries = Parse-Manifest -Path $ManifestPath

foreach ($entry in $entries) {
    $sourcePath = Join-Path $RepoRoot $entry.Source
    $targetPath = Join-Path $HomeDir $entry.Target

    if (-not (Test-Path -LiteralPath $sourcePath)) {
        Add-Result -Status "SOURCE-MISSING" -Kind "entry" -Source $sourcePath -Target $targetPath -Detail "Manifest source entry is missing."
        continue
    }

    if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
        Audit-File -SourceFile $sourcePath -TargetFile $targetPath -Kind "file"
        continue
    }

    if (Test-Path -LiteralPath $sourcePath -PathType Container) {
        $relativeSourceFiles = @{}
        Get-ChildItem -LiteralPath $sourcePath -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($sourcePath.Length).TrimStart('\', '/')
            $relativeSourceFiles[$rel] = $true
            $targetFile = Join-Path $targetPath $rel
            Audit-File -SourceFile $_.FullName -TargetFile $targetFile -Kind "dir-file"
        }

        if (Test-Path -LiteralPath $targetPath -PathType Container) {
            Get-ChildItem -LiteralPath $targetPath -Recurse -File | ForEach-Object {
                $rel = $_.FullName.Substring($targetPath.Length).TrimStart('\', '/')
                if (-not $relativeSourceFiles.ContainsKey($rel)) {
                    Add-Result -Status "EXTRA" -Kind "dir-extra" -Source "(none)" -Target $_.FullName -Detail "Present in target directory only."
                }
            }
        } elseif (Test-Path -LiteralPath $targetPath -PathType Leaf) {
            Add-Result -Status "DIFFERENT" -Kind "entry" -Source $sourcePath -Target $targetPath -Detail "Target path is file but source path is directory."
        }
    }
}

Write-Host ""
Write-Host "Audit report: installed config vs repository"
Write-Host "Repo: $RepoRoot"
Write-Host "Home: $HomeDir"
Write-Host "Manifest entries: $($entries.Count)"
Write-Host ""

$results |
    Sort-Object Status, Target |
    Format-Table -AutoSize Status, Kind, Target, Detail

Write-Host ""
Write-Host "Summary by status:"
foreach ($k in ($statusCount.Keys | Sort-Object)) {
    Write-Host ("- {0}: {1}" -f $k, $statusCount[$k])
}
