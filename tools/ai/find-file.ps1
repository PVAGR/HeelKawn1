# Find any file by name pattern
# Usage: .\tools\ai\find-file.ps1 Progression
param($Pattern = ".")
cd "$PSScriptRoot\..\.."
Write-Host "=== FILES matching '$Pattern' ==="
Get-ChildItem -Recurse -Filter "*$Pattern*" -File | Select-Object -First 20 FullName | ForEach-Object { Write-Host $_.FullName }
