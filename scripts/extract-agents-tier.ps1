# extract-agents-tier.ps1 -- Generate tier files from AGENTS.md
# Usage: .\scripts\extract-agents-tier.ps1 [-DryRun] [-Check]
#
# Reads AGENTS.md, splits sections by <!-- @tier:X --> markers, and writes:
#   AGENTS-hot.md        -- HOT tier only
#   AGENTS-warm.md       -- WARM tier only
#   AGENTS-cold.md       -- COLD tier only
#   AGENTS-hot-warm.md   -- HOT + WARM combined
#
# -DryRun  : print what would be written, do not write files
# -Check   : verify generated files match AGENTS.md markers (exit 1 on mismatch)

param(
    [switch]$DryRun,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$repoRoot   = Split-Path -Parent $PSScriptRoot
$source     = Join-Path $repoRoot 'AGENTS.md'
$outHot     = Join-Path $repoRoot 'AGENTS-hot.md'
$outWarm    = Join-Path $repoRoot 'AGENTS-warm.md'
$outCold    = Join-Path $repoRoot 'AGENTS-cold.md'
$outHotWarm = Join-Path $repoRoot 'AGENTS-hot-warm.md'

if (-not (Test-Path $source)) {
    Write-Error "ERROR: $source not found"
    exit 1
}

# ---------------------------------------------------------------------------
# Parse AGENTS.md into tier buckets
# ---------------------------------------------------------------------------

$hotLines  = [System.Collections.Generic.List[string]]::new()
$warmLines = [System.Collections.Generic.List[string]]::new()
$coldLines = [System.Collections.Generic.List[string]]::new()
$currentTier = ''
$markerRx = [regex]'^\s*<!--\s*@tier:(hot|warm|cold)\s*-->\s*$'

foreach ($line in [System.IO.File]::ReadLines($source)) {
    $m = $markerRx.Match($line)
    if ($m.Success) {
        $currentTier = $m.Groups[1].Value
        continue   # do not emit the marker line itself
    }

    switch ($currentTier) {
        'hot'   { $hotLines.Add($line) }
        'warm'  { $warmLines.Add($line) }
        'cold'  { $coldLines.Add($line) }
        default { $hotLines.Add($line) }   # preamble before first marker -> hot
    }
}

# ---------------------------------------------------------------------------
# Helper: trim trailing blank lines and join to string
# ---------------------------------------------------------------------------
function Get-TrimmedContent {
    param([System.Collections.Generic.List[string]]$lines)
    $lastNonBlank = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -ne '') { $lastNonBlank = $i }
    }
    if ($lastNonBlank -lt 0) { return '' }
    return ($lines[0..$lastNonBlank] -join "`n")
}

$contentHot     = Get-TrimmedContent $hotLines
$contentWarm    = Get-TrimmedContent $warmLines
$contentCold    = Get-TrimmedContent $coldLines
$contentHotWarm = $contentHot + "`n`n---`n`n" + $contentWarm

# ---------------------------------------------------------------------------
# Token size check: hot must be <= 2000 tok (approx chars/4)
# ---------------------------------------------------------------------------

$hotTokApprox = [int]($contentHot.Length / 4)
if ($hotTokApprox -gt 2000) {
    Write-Warning "AGENTS-hot.md estimated ~$hotTokApprox tok (>2000 cap). Review tier assignments."
}

# ---------------------------------------------------------------------------
# Validate: each tier must be non-empty
# ---------------------------------------------------------------------------

$errCount = 0
foreach ($tier in @('hot', 'warm', 'cold')) {
    $val = switch ($tier) {
        'hot'  { $contentHot }
        'warm' { $contentWarm }
        'cold' { $contentCold }
    }
    if ([string]::IsNullOrWhiteSpace($val)) {
        Write-Host "ERROR: Tier '$tier' is empty - check @tier:$tier markers in AGENTS.md" -ForegroundColor Red
        $errCount++
    }
}
if ($errCount -gt 0) { exit 1 }

# ---------------------------------------------------------------------------
# Write or check
# ---------------------------------------------------------------------------

$checkFailed = $false

function Write-OrCheck {
    param([string]$path, [string]$content, [string]$label)

    $charLen  = $content.Length
    $tokApprox = [int]($charLen / 4)

    if ($DryRun) {
        Write-Host "[DRY] Would write $path ($charLen chars, ~$tokApprox tok)"
        return
    }

    if ($Check) {
        if (-not (Test-Path $path)) {
            Write-Host "FAIL: $path missing (run extract-agents-tier.ps1 to regenerate)" -ForegroundColor Red
            $script:checkFailed = $true
            return
        }
        $existing = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8).TrimEnd("`r", "`n")
        $expected = $content.TrimEnd("`r", "`n")
        if ($existing -ne $expected) {
            Write-Host "FAIL: $path is out of sync with AGENTS.md (run extract-agents-tier.ps1)" -ForegroundColor Red
            $script:checkFailed = $true
            return
        }
        Write-Host "OK: $path" -ForegroundColor Green
        return
    }

    [System.IO.File]::WriteAllText($path, $content + "`n", [System.Text.Encoding]::UTF8)
    Write-Host "Wrote $path ($charLen chars, ~$tokApprox tok)"
}

Write-OrCheck $outHot     $contentHot     'hot'
Write-OrCheck $outWarm    $contentWarm    'warm'
Write-OrCheck $outCold    $contentCold    'cold'
Write-OrCheck $outHotWarm $contentHotWarm 'hot+warm'

if ($Check -and $checkFailed) { exit 1 }

if (-not $DryRun -and -not $Check) {
    Write-Host ""
    Write-Host "Summary:"
    $hotTok     = [int]($contentHot.Length     / 4)
    $warmTok    = [int]($contentWarm.Length    / 4)
    $coldTok    = [int]($contentCold.Length    / 4)
    $hotwarmTok = [int]($contentHotWarm.Length / 4)
    Write-Host "  AGENTS-hot.md      ~$hotTok tok"
    Write-Host "  AGENTS-warm.md     ~$warmTok tok"
    Write-Host "  AGENTS-cold.md     ~$coldTok tok"
    Write-Host "  AGENTS-hot-warm.md ~$hotwarmTok tok"
}
