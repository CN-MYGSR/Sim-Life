# Deliberately no param() binder: preserve Godot's native --flags and -- delimiter.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$editor = $env:SIM_LIFE_GODOT
if (-not $editor) {
    $editor = Join-Path (Split-Path $projectRoot -Parent) 'tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $editor -PathType Leaf)) {
    throw 'Set SIM_LIFE_GODOT to the official Godot 4.7.2 console executable.'
}
$nativeArgs = @($args)
# PowerShell consumes an unquoted -- when invoking a script. Recover the boundary
# for this game's documented options; an explicitly quoted '--' passes unchanged.
if (-not ($nativeArgs -contains '--')) {
    for ($gameArgIndex = 0; $gameArgIndex -lt $nativeArgs.Count; $gameArgIndex++) {
        if ($nativeArgs[$gameArgIndex] -match '^--(seed|output|ssao|shot|delay|at|job|page|time|test)=' -or $nativeArgs[$gameArgIndex] -in @('--no-save','--topview')) {
            $nativeArgs = @($nativeArgs | Select-Object -First $gameArgIndex) + @('--') + @($nativeArgs | Select-Object -Skip $gameArgIndex)
            break
        }
    }
}
& $editor --path $projectRoot @nativeArgs
exit $LASTEXITCODE
