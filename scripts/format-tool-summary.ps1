param(
    [string]$InputFile = "",
    [ValidateSet("compact", "full")]
    [string]$Mode = "compact"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($InputFile)) {
    Write-Host "Usage:"
    Write-Host "  pwsh -NoProfile -File .\scripts\format-tool-summary.ps1 -InputFile .\coordination\tool-usage.jsonl [-Mode compact|full]"
    exit 1
}

if (-not (Test-Path -LiteralPath $InputFile -PathType Leaf)) {
    throw "Input file not found: $InputFile"
}

$events = New-Object System.Collections.Generic.List[object]
foreach ($line in Get-Content -LiteralPath $InputFile) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try {
        $events.Add(($line | ConvertFrom-Json))
    } catch {
        # Skip malformed lines to keep report generation resilient.
    }
}

$total = $events.Count
$failed = @($events | Where-Object { $_.status -ne "ok" -and $_.status -ne "pass" }).Count
$writes = @($events | Where-Object { $_.effect -eq "write" }).Count
$network = @($events | Where-Object { $_.effect -eq "network" }).Count

if ($Mode -eq "compact") {
    Write-Host "Tool Use Summary (compact)"
    Write-Host ("- total: {0}" -f $total)
    Write-Host ("- failed: {0}" -f $failed)
    Write-Host ("- write actions: {0}" -f $writes)
    Write-Host ("- network actions: {0}" -f $network)
    if ($failed -gt 0) {
        $top = $events | Where-Object { $_.status -ne "ok" -and $_.status -ne "pass" } | Select-Object -First 3
        Write-Host "- failed commands:"
        $top | ForEach-Object { Write-Host ("  - {0}: {1}" -f $_.tool, $_.command) }
    }
    exit 0
}

Write-Host "Tool Use Summary (full)"
$events | Select-Object tool, command, effect, status | Format-Table -AutoSize
