param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$ProfileFile = "",
    [string]$ProfileName = "default",
    [string]$HomeDir = "",
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

if ([string]::IsNullOrWhiteSpace($ProfileFile)) {
    $ProfileFile = Join-Path $RepoRoot "policy/tool-permissions-profiles.json"
}

if (-not (Test-Path -LiteralPath $ProfileFile -PathType Leaf)) {
    throw "Profile file not found: $ProfileFile"
}

$profiles = Get-Content -LiteralPath $ProfileFile -Raw | ConvertFrom-Json
$profile = $profiles.$ProfileName

if (-not $profile) {
    throw "Profile '$ProfileName' not found in $ProfileFile"
}

$results = New-Object System.Collections.Generic.List[object]
$failCount = 0

function Add-Result([string]$Target, [string]$Status, [string]$Detail) {
    $results.Add([PSCustomObject]@{
        Target = $Target
        Status = $Status
        Detail = $Detail
    })
    if ($Status -eq "FAIL") {
        $script:failCount++
    }
}

# Claude
$claudePath = Join-Path $RepoRoot ".claude/settings.local.json"
$expectedAllow = @($profile.claude_allow)

$claudeObj = @{
    permissions = @{
        allow = @()
    }
}

if (Test-Path -LiteralPath $claudePath -PathType Leaf) {
    try {
        $claudeObj = Get-Content -LiteralPath $claudePath -Raw | ConvertFrom-Json
    } catch {
        Add-Result -Target ".claude/settings.local.json" -Status "FAIL" -Detail "Invalid JSON format."
    }
}

if (-not $claudeObj.permissions) {
    $claudeObj.permissions = @{ allow = @() }
}
if (-not $claudeObj.permissions.allow) {
    $claudeObj.permissions.allow = @()
}

$currentAllow = @($claudeObj.permissions.allow)
$missing = @($expectedAllow | Where-Object { $_ -notin $currentAllow })

if ($missing.Count -eq 0) {
    Add-Result -Target ".claude/settings.local.json" -Status "PASS" -Detail "Allowlist matches profile."
} else {
    if ($Apply) {
        $merged = @($currentAllow + $missing | Select-Object -Unique)
        $claudeObj.permissions.allow = $merged
        $json = $claudeObj | ConvertTo-Json -Depth 10
        Set-Content -LiteralPath $claudePath -Value $json
        Add-Result -Target ".claude/settings.local.json" -Status "PASS" -Detail ("Applied missing allow entries: {0}" -f ($missing -join ", "))
    } else {
        Add-Result -Target ".claude/settings.local.json" -Status "FAIL" -Detail ("Missing allow entries: {0}" -f ($missing -join ", "))
    }
}

# Codex
$codexPath = Join-Path $RepoRoot ".codex/config.toml"
$expectedPolicy = [string]$profile.codex_approval_policy

if (-not (Test-Path -LiteralPath $codexPath -PathType Leaf)) {
    Add-Result -Target ".codex/config.toml" -Status "FAIL" -Detail "File not found."
} else {
    $content = Get-Content -LiteralPath $codexPath -Raw
    $match = [regex]::Match($content, '(?m)^\s*approval_policy\s*=\s*"([^"]+)"\s*$')
    $currentPolicy = if ($match.Success) { $match.Groups[1].Value } else { "" }

    if ($currentPolicy -eq $expectedPolicy) {
        Add-Result -Target ".codex/config.toml" -Status "PASS" -Detail "approval_policy matches profile."
    } else {
        if ($Apply) {
            if ($match.Success) {
                $updated = [regex]::Replace($content, '(?m)^\s*approval_policy\s*=\s*"[^"]+"\s*$', ('approval_policy = "{0}"' -f $expectedPolicy))
            } else {
                $updated = ('approval_policy = "{0}"{1}{2}' -f $expectedPolicy, [Environment]::NewLine, $content)
            }
            Set-Content -LiteralPath $codexPath -Value $updated
            Add-Result -Target ".codex/config.toml" -Status "PASS" -Detail ("Set approval_policy to '{0}'." -f $expectedPolicy)
        } else {
            Add-Result -Target ".codex/config.toml" -Status "FAIL" -Detail ("approval_policy is '{0}', expected '{1}'." -f $currentPolicy, $expectedPolicy)
        }
    }
}

# OpenCode
$expectedOpenCode = $profile.opencode_permission

function Audit-OpenCode([string]$path, [string]$label) {
    if (-not $expectedOpenCode) {
        Add-Result -Target $label -Status "PASS" -Detail "No OpenCode expectations."
        return
    }

    $opencodeObj = [PSCustomObject]@{
        '$schema' = "https://opencode.ai/config.json"
        instructions = @("AGENTS.md")
        permission = @{}
    }

    if (Test-Path -LiteralPath $path -PathType Leaf) {
        try {
            $opencodeObj = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        } catch {
            Add-Result -Target $label -Status "FAIL" -Detail "Invalid JSON format."
            return
        }
    } else {
        Add-Result -Target $label -Status "FAIL" -Detail "File not found."
        if (-not $Apply) { return }
    }

    if (-not $opencodeObj.permission) { $opencodeObj.permission = @{} }

    # Sync instructions from repo to home if we are auditing the home file
    $instructionsMatch = $true
    if ($label -like "~/*") {
        $repoConfig = Join-Path $RepoRoot ".config/opencode/opencode.json"
        if (Test-Path -LiteralPath $repoConfig -PathType Leaf) {
            $repoObj = Get-Content -LiteralPath $repoConfig -Raw | ConvertFrom-Json
            $repoInstructions = @($repoObj.instructions)
            $currentInstructions = @($opencodeObj.instructions)
            
            if ($repoInstructions.Count -ne $currentInstructions.Count) {
                $instructionsMatch = $false
            } else {
                for ($i = 0; $i -lt $repoInstructions.Count; $i++) {
                    if ($repoInstructions[$i] -ne $currentInstructions[$i]) {
                        $instructionsMatch = $false
                        break
                    }
                }
            }
        }
    }

    $diff = @()
    foreach ($prop in $expectedOpenCode.psobject.Properties) {
        $k = $prop.Name
        $expected = [string]$prop.Value
        $actual = [string]$opencodeObj.permission.$k
        if ($actual -ne $expected) {
            $diff += "$k"
        }
    }

    if ($diff.Count -eq 0 -and $instructionsMatch) {
        Add-Result -Target $label -Status "PASS" -Detail "Permission map and instructions match."
    } else {
        if ($Apply) {
            foreach ($prop in $expectedOpenCode.psobject.Properties) {
                $k = $prop.Name
                $opencodeObj.permission.$k = [string]$prop.Value
            }
            if (-not $instructionsMatch) {
                $repoConfig = Join-Path $RepoRoot "opencode.json"
                $repoObj = Get-Content -LiteralPath $repoConfig -Raw | ConvertFrom-Json
                $opencodeObj.instructions = $repoObj.instructions
            }
            $dir = Split-Path -Parent $path
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            $json = $opencodeObj | ConvertTo-Json -Depth 20
            Set-Content -LiteralPath $path -Value $json
            Add-Result -Target $label -Status "PASS" -Detail ("Applied fixes for permissions/instructions.")
        } else {
            $detail = "Mismatched: " + ($diff -join ", ")
            if (-not $instructionsMatch) { $detail += " (instructions mismatch)" }
            Add-Result -Target $label -Status "FAIL" -Detail $detail
        }
    }
}

Audit-OpenCode -path (Join-Path $RepoRoot "opencode.json") -label "opencode.json"
$userOpenCode = Join-Path $HomeDir ".config/opencode/opencode.json"
Audit-OpenCode -path $userOpenCode -label "~/.config/opencode/opencode.json"

Write-Host ""
Write-Host "Permissions policy audit"
Write-Host "Repo: $RepoRoot"
Write-Host "Profile: $ProfileName"
Write-Host ""
$results | Format-Table -AutoSize Target, Status, Detail

Write-Host ""
if ($failCount -gt 0 -and -not $Apply) {
    Write-Host ("Audit failed: {0} target(s) out of policy. Use -Apply to auto-fix supported targets." -f $failCount)
    exit 1
}
Write-Host "Audit passed."
