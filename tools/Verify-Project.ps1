# Headless load of the HeelKawn Godot project (parse + short run). Exit code from Godot.
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$godot = & (Join-Path $PSScriptRoot "Resolve-Godot.ps1") -ProjectRoot $ProjectRoot
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# --quit-after 2: enough idle frames for import; see Godot #77508
& $godot --headless --path $ProjectRoot --quit-after 2 @args
exit $LASTEXITCODE
