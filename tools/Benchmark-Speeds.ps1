# Runs deterministic observer benchmark and writes reports under logs/observer.
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [ValidateSet("worker","normal")]
    [string]$BenchMode = "worker",
    [int]$TicksPerSample = 120
)

$ErrorActionPreference = "Stop"
$godot = & (Join-Path $PSScriptRoot "Resolve-Godot.ps1") -ProjectRoot $ProjectRoot
if ([string]::IsNullOrWhiteSpace($godot)) { exit 1 }

$runner = Join-Path $ProjectRoot "scripts\system\speed_benchmark_runner.gd"
if (-not (Test-Path -LiteralPath $runner)) {
    Write-Error "Benchmark runner not found: $runner"
    exit 1
}

& $godot --headless --path $ProjectRoot --script $runner --bench-mode $BenchMode --ticks-per-sample $TicksPerSample
exit $LASTEXITCODE
