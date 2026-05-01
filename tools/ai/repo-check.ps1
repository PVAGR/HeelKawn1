# Quick repo state check - run this before any work
Write-Host "=== HEELKAWN REPO STATE ==="
Write-Host "Last 5 commits:"
cd "$PSScriptRoot\..\.."
git log --oneline -5
Write-Host ""
$files = Get-ChildItem "autoloads\*.gd" -ErrorAction SilentlyContinue
Write-Host "Files in autoloads: $($files.Count)"
$progFile = "autoloads\ProgressionSystem.gd"
if (Test-Path $progFile) { Write-Host "ProgressionSystem: EXISTS" } else { Write-Host "ProgressionSystem: MISSING" }
$inProject = Select-String -Path "project.godot" -Pattern "ProgressionSystem" -Quiet
if ($inProject) { Write-Host "In project.godot: YES" } else { Write-Host "In project.godot: NO" }
$uncommitted = (git status -s 2>$null | Measure-Object).Count
Write-Host "Uncommitted: $uncommitted"
Write-Host "=== DONE ==="
