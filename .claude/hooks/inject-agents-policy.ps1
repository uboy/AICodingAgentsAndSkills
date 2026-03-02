# inject-agents-policy.ps1 — Inject AGENTS-hot.md as additionalContext for Claude Code session
# SessionStart hook: fires on startup, resume, clear, compact
# Outputs JSON {"additionalContext": "..."} to inject policy rules into Claude's context.

$ProjectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$AgentsHot = $null

if (Test-Path (Join-Path $ProjectDir "AGENTS-hot.md")) {
    $AgentsHot = Join-Path $ProjectDir "AGENTS-hot.md"
} elseif (Test-Path (Join-Path $env:USERPROFILE "AGENTS-hot.md")) {
    $AgentsHot = Join-Path $env:USERPROFILE "AGENTS-hot.md"
}

if (-not $AgentsHot) { exit 0 }

$content = Get-Content -Raw -Path $AgentsHot -Encoding UTF8
$output = [System.Text.Json.JsonSerializer]::Serialize([PSCustomObject]@{ additionalContext = $content })
Write-Output $output
