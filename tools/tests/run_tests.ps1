# HeelKawn Test Runner
# Run all headless tests in sequence
# Usage: .\tools\tests\run_tests.ps1

$ErrorActionPreference = "Stop"
$projectPath = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$godotExe = "godot"  # Or full path like "C:\Program Files\Godot\Godot_v4.6.2.exe"

$tests = @(
    @{ Name = "Autoload Integrity"; Script = "res://tools/tests/autoload_check.gd" },
    @{ Name = "Smoke Test"; Script = "res://tools/tests/smoke_test.gd" },
    @{ Name = "Determinism Test"; Script = "res://tools/tests/determinism_test.gd" }
)

$passed = 0
$failed = 0

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  HEELKAWN TEST SUITE" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

foreach ($test in $tests) {
    Write-Host "Running: $($test.Name)..." -ForegroundColor Yellow
    $output = & $godotExe --headless --path $projectPath -s $test.Script 2>&1
    $exitCode = $LASTEXITCODE

    if ($output) {
        $output | ForEach-Object { Write-Host "  $_" }
    }

    if ($exitCode -eq 0) {
        Write-Host "[PASS] $($test.Name)`n" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "[FAIL] $($test.Name) (exit code: $exitCode)`n" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  RESULTS: $passed passed, $failed failed" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($failed -gt 0) {
    exit 1
}
exit 0
