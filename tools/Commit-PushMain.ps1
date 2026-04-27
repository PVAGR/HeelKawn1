# Saves all tracked/untracked files in this repo, commits, and pushes main to GitHub.
# Run from repo root: powershell -File tools/Commit-PushMain.ps1 -Message "Describe your change"
param(
    [Parameter(Mandatory = $true)]
    [string] $Message
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$remote = (git remote get-url origin 2>$null)
if ($remote -notmatch "PVAGR.*HeelKawn1|HeelKawn1\.git") {
    Write-Error "origin does not look like PVAGR/HeelKawn1 (got: $remote). Aborting."
}

if ((git branch --show-current) -ne "main") {
    Write-Warning "Current branch is not main. Switch with: git checkout main"
}

git add -A
$st = git status --porcelain
if (-not $st) {
    Write-Host "Nothing to commit."
    exit 0
}
git commit -m $Message
git push origin main
Write-Host "Done. Pushed to origin main."
