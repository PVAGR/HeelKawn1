# Quick Godot compile check (uses tools/Resolve-Godot.ps1 like Benchmark-Speeds.ps1)
$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$godot = & (Join-Path $ProjectRoot "tools\Resolve-Godot.ps1") -ProjectRoot $ProjectRoot
Write-Host "=== Godot Compile Check ==="
Write-Host "Using: $godot"
& $godot --headless --path $ProjectRoot --script-check 2>&1 | Select-Object -First 80
Write-Host "=== DONE ==="
