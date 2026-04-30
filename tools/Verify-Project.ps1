# Headless load of the HeelKawn Godot project (parse + short run). Exit code from Godot.
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [int]$QuitAfterFrames = 240
)

$ErrorActionPreference = "Stop"
$godot = & (Join-Path $PSScriptRoot "Resolve-Godot.ps1") -ProjectRoot $ProjectRoot
if ([string]::IsNullOrWhiteSpace($godot)) { exit 1 }

# 240 frames is still fast headless, but lets tick 1 fire so autoload/main
# wiring is exercised instead of only importing the scene tree.
& $godot --headless --path $ProjectRoot --quit-after $QuitAfterFrames @args
exit $LASTEXITCODE
