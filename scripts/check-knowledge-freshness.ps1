param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$indexPath = Join-Path $RepoRoot ".agent-memory/index.jsonl"
if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
  Write-Output "MISSING_INDEX:$indexPath"
  exit 1
}

$today = Get-Date
$stale = @()

Get-Content -LiteralPath $indexPath | ForEach-Object {
  $line = $_.Trim()
  if (-not $line) { return }
  $entry = $line | ConvertFrom-Json
  if (-not $entry.last_verified_on -or -not $entry.verify_after_days) { return }

  $due = (Get-Date $entry.last_verified_on).AddDays([int]$entry.verify_after_days)
  if ($today -gt $due) {
    $stale += [pscustomobject]@{
      id = [string]$entry.id
      technology = [string]$entry.technology
      due_on = $due.ToString("yyyy-MM-dd")
    }
  }
}

if ($stale.Count -eq 0) {
  Write-Output "OK: no stale entries"
  exit 0
}

Write-Output "STALE_ENTRIES:"
$stale | Sort-Object due_on, id | ForEach-Object { "{0}`t{1}`t{2}" -f $_.id, $_.technology, $_.due_on | Write-Output }
exit 2
