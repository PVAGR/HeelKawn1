# Runs deterministic observer benchmark and writes reports under logs/observer.
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [ValidateSet("worker","normal")]
    [string]$BenchMode = "worker"
)

$ErrorActionPreference = "Stop"
$godot = & (Join-Path $PSScriptRoot "Resolve-Godot.ps1") -ProjectRoot $ProjectRoot
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $godot --headless --path $ProjectRoot --script "res://scripts/system/speed_benchmark_runner.gd" --bench-mode $BenchMode
exit $LASTEXITCODE
