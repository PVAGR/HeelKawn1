# Quick Godot compile check
Write-Host "=== Godot Compile Check ==="
godot --headless --script-check 2>&1 | Select-Object -First 30
Write-Host "=== DONE ==="
