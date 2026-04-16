param(
    [Parameter(Mandatory = $true)]
    [string]$CommandText
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$blockPatterns = @(
    '(?i)\bcurl\b[^\n\r]*\|\s*(bash|sh|zsh|pwsh|powershell)\b',
    '(?i)\bwget\b[^\n\r]*\|\s*(bash|sh|zsh|pwsh|powershell)\b',
    '(?i)\b(invoke-expression|iex|eval)\b',
    '(?i)\bfrombase64string\b[^\n\r]*\|\s*(bash|sh|zsh|pwsh|powershell)\b'
)

$warnPatterns = @(
    '(?i)\brm\s+-rf\b',
    '(?i)\bremove-item\b[^\n\r]*-recurse[^\n\r]*-force',
    '(?i)\b(del|erase)\b[^\n\r]*/(f|s|q)',
    '(?i)\bgit\s+reset\s+--hard\b',
    '(?i)\bformat-(volume|disk)\b'
)

$reasons = New-Object System.Collections.Generic.List[string]
$status = "SAFE"

foreach ($p in $blockPatterns) {
    if ($CommandText -match $p) {
        $status = "BLOCK"
        $reasons.Add("Matched block pattern: $p")
    }
}

if ($status -ne "BLOCK") {
    foreach ($p in $warnPatterns) {
        if ($CommandText -match $p) {
            $status = "WARN"
            $reasons.Add("Matched warn pattern: $p")
        }
    }
}

Write-Host ""
Write-Host "Command safety check"
Write-Host "Status: $status"
Write-Host "Command: $CommandText"
if ($reasons.Count -gt 0) {
    Write-Host "Reasons:"
    $reasons | ForEach-Object { Write-Host "- $_" }
}

switch ($status) {
    "SAFE" { exit 0 }
    "WARN" { exit 10 }
    "BLOCK" { exit 20 }
}
