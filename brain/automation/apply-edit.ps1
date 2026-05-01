# HeelKawn Safe Edit Runner
# Creates a git checkpoint before edits, allows rollback
# Usage: powershell -File brain/automation/apply-edit.ps1 -File "path.gd" -Description "What changed"

param(
    [Parameter(Mandatory=$true)]
    [string]$File,
    [Parameter(Mandatory=$true)]
    [string]$Description
)

$ErrorActionPreference = "Stop"

Write-Host "=== SAFE EDIT RUNNER ===" -ForegroundColor Cyan
Write-Host ""

# Validate file exists
if (-not (Test-Path $File)) {
    Write-Host "ERROR: File not found: $File" -ForegroundColor Red
    exit 1
}

# Create checkpoint
Write-Host "1. Creating git checkpoint..." -ForegroundColor Yellow
$checkpointName = "pre-edit-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
git stash push -m "Checkpoint: $checkpointName - $Description" 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "   Checkpoint saved: $checkpointName" -ForegroundColor Green
} else {
    # If nothing to stash, note it
    Write-Host "   No uncommitted changes to stash (clean working tree)" -ForegroundColor Yellow
}

# Record in session log
$today = Get-Date -Format "yyyy-MM-dd"
$sessionFile = "brain/memory/sessions/$today.md"
if (Test-Path $sessionFile) {
    Add-Content -Path $sessionFile -Value "`n- Edited: $File — $Description"
}

# Record in code changes
$changesFile = "brain/memory/knowledge/code_changes.md"
if (Test-Path $changesFile) {
    $line = "`n### $today | $(Split-Path $File -Leaf) | $Description | AI-assisted edit"
    Add-Content -Path $changesFile -Value $line
}

Write-Host "2. Edit recorded in memory system" -ForegroundColor Green
Write-Host ""
Write-Host "File ready for editing: $File" -ForegroundColor Cyan
Write-Host "Description: $Description" -ForegroundColor Cyan
Write-Host ""
Write-Host "After making your changes:" -ForegroundColor Yellow
Write-Host "  1. Review: git diff $File" -ForegroundColor White
Write-Host "  2. Commit: git add $File && git commit -m '$Description'" -ForegroundColor White
Write-Host "  3. Rollback (if needed): git stash pop" -ForegroundColor White
Write-Host ""
Write-Host "=== READY ===" -ForegroundColor Cyan
