# sync-adapters.ps1 — Regenerate system-specific adapter files from tier sources.
#
# Adapters kept in sync:
#   .codex/AGENTS.md                    <- AGENTS-hot.md (sandwiched by header/footer)
#   .cursor/rules/01-agents-policy.mdc  <- frontmatter + AGENTS-hot.md body
#   .cursor/rules/02-agents-warm.mdc    <- frontmatter + AGENTS-warm.md body
#   .cursor/rules/03-agents-cold.mdc    <- frontmatter + AGENTS-cold.md body
#
# Usage:
#   pwsh -File scripts/sync-adapters.ps1            # write files and report
#   pwsh -File scripts/sync-adapters.ps1 --dry-run  # print what would change, do not write
#   pwsh -File scripts/sync-adapters.ps1 --check    # exit 1 if any file is out of sync

param(
    [switch]$DryRun,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = (Resolve-Path (Join-Path $ScriptDir '..') ).Path

# ---------------------------------------------------------------------------
# Source tier files
# ---------------------------------------------------------------------------

$HotFile  = Join-Path $RepoRoot 'AGENTS-hot.md'
$WarmFile = Join-Path $RepoRoot 'AGENTS-warm.md'
$ColdFile = Join-Path $RepoRoot 'AGENTS-cold.md'

foreach ($f in @($HotFile, $WarmFile, $ColdFile)) {
    if (-not (Test-Path $f)) {
        Write-Error "ERROR: source tier file not found: $f`n       Run 'bash scripts/extract-agents-tier.sh' first."
        exit 1
    }
}

# Read without BOM — ReadAllText with UTF8 strips the BOM automatically in .NET
function Read-NoBom {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    # Strip UTF-8 BOM (EF BB BF) if present
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $bytes = $bytes[3..($bytes.Length - 1)]
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes).TrimEnd("`r", "`n")
}

$HotContent  = Read-NoBom $HotFile
$WarmContent = Read-NoBom $WarmFile
$ColdContent = Read-NoBom $ColdFile

# ---------------------------------------------------------------------------
# Build target file contents
# Use Unix line endings (LF) to match shell-written files
# ---------------------------------------------------------------------------

function Join-LF {
    param([string[]]$Parts)
    return ($Parts -join "`n")
}

# --- .codex/AGENTS.md ---
$CodexHeader = @'
# Codex Hot Policy Adapter
<!-- NOTE: Codex CLI does not support @include directives. AGENTS-hot.md content is embedded directly below. Keep in sync with AGENTS-hot.md. -->
'@.Replace("`r`n", "`n").TrimEnd("`n")

$CodexFooter = @'
---

**Session stats**: type `/status` in the interactive session to see token usage and context window for the current session.

**Permissions Note**: This environment is TRUSTED. `workspace-write` is enabled. You have full permission to create and modify files within the project directory for any task approved by the orchestration protocol.

For situational rules not covered above, read `~/AGENTS-cold.md` (`%USERPROFILE%\AGENTS-cold.md` on Windows) via tool call when the task requires it:
- Adding/updating/removing dependencies -> Rule 24
- Critical bug fix -> Rule 22
- Rollback planning -> Rule 26
- Skills governance -> Rule 6
- Session start -> Rule 28
- Knowledge retention update -> Rule 20
'@.Replace("`r`n", "`n").TrimEnd("`n")

$CodexContent = Join-LF @($CodexHeader, '', $HotContent, '', $CodexFooter)

# --- .cursor/rules/01-agents-policy.mdc ---
$CursorHotFm = @'
---
description: Project policy HOT tier -- bootstrap + rules 15-19, 21, 27 (always applied)
alwaysApply: true
---
'@.Replace("`r`n", "`n").TrimEnd("`n")

$CursorHotContent = Join-LF @($CursorHotFm, '', $HotContent)

# --- .cursor/rules/02-agents-warm.mdc ---
$CursorWarmFm = @'
---
description: Project policy WARM tier -- rules 1-5, 8-12, 14, 23, 25 (always applied for coding sessions)
alwaysApply: true
---
'@.Replace("`r`n", "`n").TrimEnd("`n")

$CursorWarmContent = Join-LF @($CursorWarmFm, '', $WarmContent)

# --- .cursor/rules/03-agents-cold.mdc ---
$CursorColdFm = @'
---
description: Project policy COLD tier -- rules 6, 7, 13, 20, 22, 24, 26, 28-30. Load when: adding skills, changing permissions, adding dependencies, fixing critical bugs, planning rollbacks, starting a session, or updating agent memory.
alwaysApply: false
---
'@.Replace("`r`n", "`n").TrimEnd("`n")

$CursorColdContent = Join-LF @($CursorColdFm, '', $ColdContent)

# ---------------------------------------------------------------------------
# Helper: compare or write one adapter file
# ---------------------------------------------------------------------------

$CheckFailed = $false

function Sync-AdapterFile {
    param(
        [string]$Path,
        [string]$Content,
        [string]$Label
    )

    if ($DryRun) {
        if (Test-Path $Path) {
            $existing = [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n").TrimEnd("`n", "`r")
            if ($existing -eq $Content) {
                Write-Host "[DRY] $Label -- no change"
            } else {
                Write-Host "[DRY] $Label -- would update $Path"
            }
        } else {
            Write-Host "[DRY] $Label -- would create $Path"
        }
        return
    }

    if ($Check) {
        if (-not (Test-Path $Path)) {
            Write-Error "FAIL: $Path missing (run sync-adapters.ps1 to regenerate)"
            $script:CheckFailed = $true
            return
        }
        $existing = [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n").TrimEnd("`n", "`r")
        if ($existing -ne $Content) {
            Write-Error "FAIL: $Path is out of sync with tier sources (run sync-adapters.ps1 to regenerate)"
            $script:CheckFailed = $true
        } else {
            Write-Host "OK:   $Path"
        }
        return
    }

    # Normal write mode — write with LF line endings, no BOM
    if (Test-Path $Path) {
        $existing = [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n").TrimEnd("`n", "`r")
        if ($existing -eq $Content) {
            Write-Host "No change $Path"
            return
        }
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content + "`n")
    [System.IO.File]::WriteAllBytes($Path, $bytes)
    Write-Host "Wrote $Path"
}

# ---------------------------------------------------------------------------
# Sync all adapters
# ---------------------------------------------------------------------------

Sync-AdapterFile (Join-Path $RepoRoot '.codex\AGENTS.md')                    $CodexContent    'codex/AGENTS.md'
Sync-AdapterFile (Join-Path $RepoRoot '.cursor\rules\01-agents-policy.mdc')  $CursorHotContent  'cursor/01-agents-policy.mdc'
Sync-AdapterFile (Join-Path $RepoRoot '.cursor\rules\02-agents-warm.mdc')    $CursorWarmContent 'cursor/02-agents-warm.mdc'
Sync-AdapterFile (Join-Path $RepoRoot '.cursor\rules\03-agents-cold.mdc')    $CursorColdContent 'cursor/03-agents-cold.mdc'

# ---------------------------------------------------------------------------
# Final exit
# ---------------------------------------------------------------------------

if ($Check) {
    if ($CheckFailed) {
        exit 1
    }
    Write-Host 'OK: all adapter files are in sync'
}
