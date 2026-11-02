$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$logs = Join-Path $projectRoot '.artifacts'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$cases = @(
    @{ Name='import'; Args=@('--headless','--editor','--import','--quit') },
    @{ Name='project-audit'; Marker='PROJECT_AUDIT: .* scripts/scenes, 0 failures'; Args=@('--headless','--quit-after','300','--scene','res://tests/project_audit.tscn','--','--no-save') },
    @{ Name='regression'; Marker='REGRESSION: .* checks, 0 failures'; Args=@('--headless','--quit-after','3600','--scene','res://tests/regression.tscn','--','--seed=20261102','--no-save') },
    @{ Name='quiz'; Marker='QUIZ_DEMO_DONE fail=0'; Args=@('--headless','--quit-after','3600','--scene','res://tests/quiz_demo.tscn','--','--no-save') },
    @{ Name='gameplay-flow'; Marker='GAMEPLAY_FLOW: .* checks, 0 failures'; Args=@('--headless','--fixed-fps','60','--quit-after','5000','--scene','res://tests/gameplay_flow.tscn','--','--seed=20261102','--no-save') },
    @{ Name='world-routes'; Marker='WORLD_ROUTES: .* checks, 0 failures'; Args=@('--headless','--fixed-fps','60','--quit-after','18000','--scene','res://tests/world_routes.tscn','--','--seed=20261102','--no-save') }
)
foreach ($case in $cases) {
    $log = Join-Path $logs ($case.Name + '.log')
    $arguments = $case.Args
    & "$PSScriptRoot/godot.ps1" @arguments *> $log
    $code = $LASTEXITCODE
    $errors = Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|^ERROR:|^FAIL:'
    Get-Content -LiteralPath $log -Tail 6
    if ($code -ne 0 -or $errors) { throw "Godot $($case.Name) failed. See $log" }
    if ($case.Marker -and -not (Select-String -LiteralPath $log -Pattern $case.Marker)) { throw "Godot $($case.Name) did not finish. See $log" }
}
