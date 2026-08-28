# sync-adapters.ps1 — Generate all system adapter files from adapters/ sources.
#
# Reads adapters/systems.json for configuration, then generates:
#   - Tier files (AGENTS-hot/warm/cold.md) from AGENTS.md
#   - System adapter files (CLAUDE.md, .codex/AGENTS.md, etc.)
#   - Cursor MDC rule files with YAML frontmatter
#   - Copies settings, hooks, agents to correct out/ locations
#
# Usage:
#   pwsh -File scripts/sync-adapters.ps1 [-OutDir <path>]
#   pwsh -File scripts/sync-adapters.ps1 [-OutDir <path>] -DryRun
#   pwsh -File scripts/sync-adapters.ps1 [-OutDir <path>] -Check

param(
    [string]$OutDir = "",
    [switch]$DryRun,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = (Resolve-Path (Join-Path $ScriptDir '..')).Path

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $Out = Join-Path $RepoRoot 'out'
} else {
    $Out = $OutDir
}

$SystemsConfig = Join-Path $RepoRoot 'adapters/systems.json'
$AgentsDir     = Join-Path $RepoRoot 'agents'
$AdaptersDir   = Join-Path $RepoRoot 'adapters'
$SourceAGENTS  = Join-Path $RepoRoot 'AGENTS.md'

if (-not (Test-Path $SystemsConfig)) {
    Write-Error "ERROR: adapters/systems.json not found"
    exit 1
}

# ---------------------------------------------------------------------------
# Load systems configuration
# ---------------------------------------------------------------------------

$Config = Get-Content -LiteralPath $SystemsConfig -Raw -Encoding UTF8 | ConvertFrom-Json
$agentFilesPresent = @(Get-ChildItem -LiteralPath $AgentsDir -File -ErrorAction SilentlyContinue).Count -gt 0
$agentSourceWarned = $false

# ---------------------------------------------------------------------------
# Tier parsing from AGENTS.md
# ---------------------------------------------------------------------------

function Get-TierContent {
    param([string]$TierName)

    $hotLines  = [System.Collections.Generic.List[string]]::new()
    $warmLines = [System.Collections.Generic.List[string]]::new()
    $coldLines = [System.Collections.Generic.List[string]]::new()
    $currentTier = ''
    $markerRx = [regex]'^\s*<!--\s*@?tier:(hot|warm|cold)\s*-->\s*$'

    foreach ($line in [System.IO.File]::ReadLines($SourceAGENTS)) {
        $m = $markerRx.Match($line)
        if ($m.Success) {
            $currentTier = $m.Groups[1].Value
            continue
        }
        switch ($currentTier) {
            'hot'  { $hotLines.Add($line) }
            'warm' { $warmLines.Add($line) }
            'cold' { $coldLines.Add($line) }
            default { $hotLines.Add($line) }
        }
    }

    $result = @{}
    $result['hot']  = Get-TrimmedLines $hotLines
    $result['warm'] = Get-TrimmedLines $warmLines
    $result['cold'] = Get-TrimmedLines $coldLines
    return $result
}

function Get-TrimmedLines {
    param([System.Collections.Generic.List[string]]$lines)
    $lastNonBlank = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -ne '') { $lastNonBlank = $i }
    }
    if ($lastNonBlank -lt 0) { return '' }
    return ($lines[0..$lastNonBlank] -join "`n")
}

# Parse tiers once
$tierContent = Get-TierContent

# ---------------------------------------------------------------------------
# Helper: ensure parent directory exists
# ---------------------------------------------------------------------------
function Ensure-Dir {
    param([string]$Path)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# ---------------------------------------------------------------------------
# Helper: write or check a file
# ---------------------------------------------------------------------------
$script:checkFailed = $false

function Write-File {
    param([string]$Path, [string]$Content, [string]$Label)

    if ($DryRun) {
        if ((Test-Path -LiteralPath $Path)) {
            $existing = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8).Trim()
            if ($existing -eq $Content.Trim()) {
                Write-Host "[DRY] $Label — no change"
            } else {
                Write-Host "[DRY] $Label — would update"
            }
        } else {
            Write-Host "[DRY] $Label — would create"
        }
        return
    }

    if ($Check) {
        if (-not (Test-Path -LiteralPath $Path)) {
            Write-Host "FAIL: $Label — missing ($Path)" -ForegroundColor Red
            $script:checkFailed = $true
            return
        }
        $existing = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8).Trim()
        if ($existing -ne $Content.Trim()) {
            Write-Host "FAIL: $Label — out of sync ($Path)" -ForegroundColor Red
            $script:checkFailed = $true
            return
        }
        Write-Host "OK: $Label" -ForegroundColor Green
        return
    }

    Ensure-Dir $Path
    [System.IO.File]::WriteAllText($Path, $Content + "`n", [System.Text.UTF8Encoding]::new($false))
    Write-Host "Wrote $Label ($($Path.Replace($RepoRoot + '\', '')))"
}

# ---------------------------------------------------------------------------
# Helper: copy directory contents
# ---------------------------------------------------------------------------
function Copy-DirContents {
    param([string]$SourceDir, [string]$TargetDir, [string]$Label)

    if (-not (Test-Path -LiteralPath $SourceDir)) {
        Write-Host "SKIP: $Label — source dir not found ($SourceDir)" -ForegroundColor Yellow
        return
    }

    if (-not $DryRun -and -not $Check) {
        if (-not (Test-Path -LiteralPath $TargetDir)) {
            New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
        }
    }

    Get-ChildItem -LiteralPath $SourceDir -File | ForEach-Object {
        $targetPath = Join-Path $TargetDir $_.Name
        $content = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
        Write-File -Path $targetPath -Content $content -Label "$Label/$($_.Name)"
    }
}

# ---------------------------------------------------------------------------
# Generate tier files
# ---------------------------------------------------------------------------

Write-Host "`n--- Tier Files ---"

foreach ($tf in $Config.systems.tier_files.files) {
    $tiers = @()
    if ($tf.tier) { $tiers = @($tf.tier) }
    elseif ($tf.tiers) { $tiers = @($tf.tiers) }

    $parts = @()
    foreach ($t in $tiers) {
        if ($tierContent[$t]) { $parts += $tierContent[$t] }
    }
    $content = $parts -join "`n`n---`n`n"
    $outputPath = Join-Path $Out $tf.output
    Write-File -Path $outputPath -Content $content -Label $tf.output
}

# ---------------------------------------------------------------------------
# Generate system files
# ---------------------------------------------------------------------------

Write-Host "`n--- System Adapters ---"

$template = [System.IO.File]::ReadAllText(
    (Join-Path $AdaptersDir 'templates/system-adapter.md'),
    [System.Text.Encoding]::UTF8
)

foreach ($sysName in $Config.systems.PSObject.Properties.Name) {
    $sys = $Config.systems.$sysName
    Write-Host "`n[$sysName]"

    foreach ($sf in $sys.system_files) {
        $outputPath = Join-Path $Out $sf.output

        # --- Source-based: copy from adapters/ directory ---
        if ($sf.source) {
            $sourcePath = Join-Path $RepoRoot $sf.source
            if (Test-Path -LiteralPath $sourcePath) {
                $content = [System.IO.File]::ReadAllText($sourcePath, [System.Text.Encoding]::UTF8)
                Write-File -Path $outputPath -Content $content -Label $sf.output
            } else {
                Write-Host "WARN: source not found: $sourcePath" -ForegroundColor Yellow
            }
            continue
        }

        # --- Template-based: system-adapter.md ---
        if ($sf.template -eq 'system-adapter.md') {
            if ($sf.skip_bootstrap) {
                # Use raw extra_lines instead of template
                $content = if ($sf.extra_lines) { $sf.extra_lines -join "`n" } else { '' }
                Write-File -Path $outputPath -Content $content.Trim() -Label $sf.output
            } else {
                $body = $template -replace '\{\{SYSTEM_LABEL\}\}', $sys.label

                $extraLines = @()
                if ($sf.extra_footer) { $extraLines = @($sf.extra_footer) }

                $extraBlock = if ($extraLines.Count -gt 0) { $extraLines -join "`n" } else { '' }
                $body = $body -replace '\{\{EXTRA_FOOTER\}\}', $extraBlock

                Write-File -Path $outputPath -Content $body.Trim() -Label $sf.output
            }
            continue
        }

        # --- Codex: embedded hot tier ---
        if ($sf.template -eq 'codex-agents-md') {
            $sb = [System.Text.StringBuilder]::new()
            if ($sf.header) {
                foreach ($h in $sf.header) { [void]$sb.AppendLine($h) }
                [void]$sb.AppendLine('')
            }
            [void]$sb.Append($tierContent['hot'])
            if ($sf.footer) {
                [void]$sb.AppendLine('')
                [void]$sb.AppendLine('')
                foreach ($f in $sf.footer) { [void]$sb.AppendLine($f) }
            }
            Write-File -Path $outputPath -Content $sb.ToString().Trim() -Label $sf.output
            continue
        }

        # --- Gemini/OpenCode thin adapter ---
        $tmpl = $sf.template
        if ($tmpl -and $tmpl.GetType().Name -eq 'String' -and $tmpl.EndsWith('-agents-md')) {
            $content = if ($sf.extra_lines) { $sf.extra_lines -join "`n" } else { '' }
            Write-File -Path $outputPath -Content $content.Trim() -Label $sf.output
            continue
        }

        # --- Cursor tier rule ---
        if ($sf.template -eq 'cursor-tier-rule') {
            $sb = [System.Text.StringBuilder]::new()
            [void]$sb.AppendLine('---')
            if ($sf.frontmatter) {
                foreach ($prop in $sf.frontmatter.PSObject.Properties) {
                    $val = $prop.Value
                    if ($val -is [boolean]) { $val = $val.ToString().ToLower() }
                    [void]$sb.AppendLine("$($prop.Name): $val")
                }
            }
            [void]$sb.AppendLine('---')
            [void]$sb.AppendLine('')
            [void]$sb.Append($tierContent[$sf.tier])
            Write-File -Path $outputPath -Content $sb.ToString().Trim() -Label $sf.output
            continue
        }
    }

    # --- Settings ---
    if ($sys.settings) {
        $src = Join-Path $RepoRoot $sys.settings.source
        $dst = Join-Path $Out $sys.settings.output
        if (Test-Path -LiteralPath $src) {
            $content = [System.IO.File]::ReadAllText($src, [System.Text.Encoding]::UTF8)
            Write-File -Path $dst -Content $content -Label $sys.settings.output
        }
    }

    # --- Hooks (single file) ---
    if ($sys.hooks -and $sys.hooks.source -and -not $sys.hooks.source_dir) {
        $src = Join-Path $RepoRoot $sys.hooks.source
        $dst = Join-Path $Out $sys.hooks.output
        if (Test-Path -LiteralPath $src) {
            $content = [System.IO.File]::ReadAllText($src, [System.Text.Encoding]::UTF8)
            Write-File -Path $dst -Content $content -Label $sys.hooks.output
        }
    }

    # --- Hooks (directory) ---
    if ($sys.hooks -and $sys.hooks.source_dir) {
        Copy-DirContents (Join-Path $RepoRoot $sys.hooks.source_dir) (Join-Path $Out $sys.hooks.output_dir) "$sysName/hooks"
    }
    if ($sys.hooks_dir) {
        Copy-DirContents (Join-Path $RepoRoot $sys.hooks_dir.source_dir) (Join-Path $Out $sys.hooks_dir.output_dir) "$sysName/hooks-dir"
    }

    # --- Config (e.g., opencode.json) ---
    if ($sys.config) {
        $src = Join-Path $RepoRoot $sys.config.source
        $dst = Join-Path $Out $sys.config.output
        if (Test-Path -LiteralPath $src) {
            $content = [System.IO.File]::ReadAllText($src, [System.Text.Encoding]::UTF8)
            Write-File -Path $dst -Content $content -Label $sys.config.output
        }
    }

    # --- Extension manifest ---
    if ($sys.extension_manifest) {
        $src = Join-Path $RepoRoot $sys.extension_manifest.source
        $dst = Join-Path $Out $sys.extension_manifest.output
        if (Test-Path -LiteralPath $src) {
            $content = [System.IO.File]::ReadAllText($src, [System.Text.Encoding]::UTF8)
            Write-File -Path $dst -Content $content -Label $sys.extension_manifest.output
        }
    }

    # --- Agents ---
    if ($sys.agents -and $Config.systems.shared_agents) {
        if (-not $agentFilesPresent -and -not $agentSourceWarned) {
            Write-Warning "Shared agent generation is disabled in this checkout: '$AgentsDir' has no canonical tracked source files."
            $agentSourceWarned = $true
        }
        $targetDir = Join-Path $Out $sys.agents.output_dir
        Copy-DirContents $AgentsDir $targetDir "$sysName/agents"

        # Weak-model agents
        $wmSource = Join-Path $AgentsDir 'weak-model'
        if (Test-Path -LiteralPath $wmSource) {
            $wmTarget = Join-Path $targetDir 'weak-model'
            Copy-DirContents $wmSource $wmTarget "$sysName/agents/weak-model"
        }
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if ($Check) {
    if ($script:checkFailed) {
        Write-Host "`nFAILED: some files out of sync" -ForegroundColor Red
        exit 1
    }
    Write-Host "`nOK: all adapter files in sync" -ForegroundColor Green
    exit 0
}

if (-not $DryRun) {
    Write-Host "`n--- Summary ---"
    Write-Host "Output: $Out"
    $fileCount = (Get-ChildItem -LiteralPath $Out -Recurse -File).Count
    Write-Host "Files:  $fileCount"
}
