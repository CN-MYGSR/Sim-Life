param([Parameter(ValueFromRemainingArguments=$true)][string[]]$GodotArgs)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$editor = $env:SIM_LIFE_GODOT
if (-not $editor) {
    $editor = Join-Path (Split-Path $projectRoot -Parent) 'tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $editor -PathType Leaf)) {
    throw 'Set SIM_LIFE_GODOT to the official Godot 4.7.2 console executable.'
}
& $editor --path $projectRoot @GodotArgs
exit $LASTEXITCODE
