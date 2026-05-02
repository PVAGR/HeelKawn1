# Show recent commits with changes
# Usage: .\tools\ai\commit-log.ps1 [count]
param($Count = 10)
cd "$PSScriptRoot\..\.."
Write-Host "=== Last $Count commits ==="
git log --oneline -$Count
git log --oneline -$Count | ForEach-Object {
    $sha = $_.Split(' ')[0]
    Write-Host "--- $sha ---"
    git show --stat --oneline $sha | Select-Object -First 5 | ForEach-Object { Write-Host $_ }
}
