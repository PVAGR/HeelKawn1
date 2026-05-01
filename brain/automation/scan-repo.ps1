# HeelKawn Repository Scanner
# Scans the repo and outputs a context summary for AI assistants
# Usage: powershell -File brain/automation/scan-repo.ps1

$ErrorActionPreference = "SilentlyContinue"

Write-Host "=== HEELKAWN REPO SCAN ===" -ForegroundColor Cyan
Write-Host ""

# Get repo root
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = Get-Location
}
Write-Host "Repository: $repoRoot"
Write-Host "Branch: $(git branch --show-current)"
Write-Host ""

# File counts
Write-Host "--- File Counts ---" -ForegroundColor Yellow
$gdCount = (Get-ChildItem -Recurse -Filter "*.gd" -File 2>$null).Count
$tscnCount = (Get-ChildItem -Recurse -Filter "*.tscn" -File 2>$null).Count
$mdCount = (Get-ChildItem -Recurse -Filter "*.md" -File 2>$null).Count
$jsonCount = (Get-ChildItem -Recurse -Filter "*.json" -File 2>$null).Count
Write-Host "  GDScript files: $gdCount"
Write-Host "  Scene files:    $tscnCount"
Write-Host "  Markdown docs:  $mdCount"
Write-Host "  JSON files:     $jsonCount"
Write-Host ""

# Autoload count
Write-Host "--- Autoload Systems ---" -ForegroundColor Yellow
$autoloadCount = (Get-ChildItem "autoloads" -Filter "*.gd" -File 2>$null).Count
Write-Host "  Autoload scripts: $autoloadCount"
Write-Host ""

# Recent git changes
Write-Host "--- Recent Changes (last 5 commits) ---" -ForegroundColor Yellow
git log --oneline -5 2>$null
Write-Host ""

# Uncommitted changes
Write-Host "--- Working Tree Status ---" -ForegroundColor Yellow
$status = git status --short 2>$null
if ($status) {
    $changedCount = ($status | Measure-Object).Count
    Write-Host "  $changedCount file(s) modified/untracked"
    $status | Select-Object -First 10 | ForEach-Object { Write-Host "    $_" }
    if ($changedCount -gt 10) {
        Write-Host "    ... and $($changedCount - 10) more"
    }
} else {
    Write-Host "  Clean working tree"
}
Write-Host ""

# Check for recent session log
Write-Host "--- Last Session Log ---" -ForegroundColor Yellow
$today = Get-Date -Format "yyyy-MM-dd"
$sessionFile = "brain/memory/sessions/$today.md"
if (Test-Path $sessionFile) {
    Write-Host "  Today's session log exists: $sessionFile"
} else {
    Write-Host "  No session log for today yet"
}

# Check active context
if (Test-Path "brain/memory/active_context.md") {
    Write-Host "  Active context: LOADED"
} else {
    Write-Host "  Active context: MISSING"
}
Write-Host ""

# Check for errors in recent logs
Write-Host "--- Recent Log Scan ---" -ForegroundColor Yellow
$logFiles = Get-ChildItem "logs" -Filter "*.log" -File 2>$null | Sort-Object LastWriteTime -Descending | Select-Object -First 5
foreach ($log in $logFiles) {
    $errors = Select-String -Path $log.FullName -Pattern "ERROR|CRASH|FAIL" -SimpleMatch 2>$null
    if ($errors) {
        Write-Host "  $($log.Name): $($errors.Count) error(s) found"
    }
}
Write-Host ""

Write-Host "=== SCAN COMPLETE ===" -ForegroundColor Cyan
