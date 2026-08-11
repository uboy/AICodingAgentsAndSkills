param(
    [string[]]$Suite,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonScript = Join-Path $scriptDir 'run_promptfoo_evals.py'

$argsList = @($pythonScript)
foreach ($name in $Suite) {
    $argsList += @('--suite', $name)
}
if ($Check) {
    $argsList += '--check'
}

& python @argsList
exit $LASTEXITCODE
