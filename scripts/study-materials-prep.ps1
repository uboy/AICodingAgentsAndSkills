<#
.SYNOPSIS
    Prepare study materials for RAG indexing.
    Wrapper around study-materials-prep.py.

.DESCRIPTION
    Recursively scans source directory, extracts all content,
    outputs structured Markdown to ./study-output/<subject>/ by default.

.PARAMETER Source
    Source directory with study materials (required).

.PARAMETER Output
    Output directory (default: ./study-output/<subject>/).

.EXAMPLE
    .\scripts\study-materials-prep.ps1 -Source "C:\path\to\HR-менеджмент"
    .\scripts\study-materials-prep.ps1 -Source "C:\path\to\HR" -Output "C:\output"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Source,

    [string]$Output = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $PSCommandPath
$PythonScript = Join-Path $ScriptDir "study-materials-prep.py"

if (-not (Test-Path $PythonScript)) {
    Write-Error "study-materials-prep.py not found at $PythonScript"
    exit 1
}

$PythonCmd = $null
foreach ($cmd in @("python3", "python")) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        $PythonCmd = $cmd
        break
    }
}
if (-not $PythonCmd) {
    Write-Error "Python 3 not found. Install from https://www.python.org/downloads/"
    exit 1
}

$Args = @($PythonScript, "--source", $Source)
if ($Output) { $Args += "--output", $Output }

& $PythonCmd @Args
