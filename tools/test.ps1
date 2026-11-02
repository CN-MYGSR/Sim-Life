$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$logs = Join-Path $projectRoot '.artifacts'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$cases = @(
    @{ Name='import'; Args=@('--headless','--editor','--import','--quit') },
    @{ Name='regression'; Args=@('--headless','--quit-after','3600','--scene','res://tests/regression.tscn','--','--seed=20261102','--no-save') },
    @{ Name='quiz'; Args=@('--headless','--quit-after','3600','--scene','res://tests/quiz_demo.tscn','--','--no-save') }
)
foreach ($case in $cases) {
    $log = Join-Path $logs ($case.Name + '.log')
    $arguments = $case.Args
    & "$PSScriptRoot/godot.ps1" @arguments *> $log
    $code = $LASTEXITCODE
    $errors = Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|^ERROR:|^FAIL:'
    Get-Content -LiteralPath $log -Tail 6
    if ($code -ne 0 -or $errors) { throw "Godot $($case.Name) failed. See $log" }
}
