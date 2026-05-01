# HeelKawn Session Summarizer
# Generates a summary of today's changes for the brain memory system
# Usage: powershell -File brain/automation/summarize.ps1

$ErrorActionPreference = "SilentlyContinue"

$today = Get-Date -Format "yyyy-MM-dd"
$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$timeOnly = Get-Date -Format "HH:mm"
$sessionFile = "brain/memory/sessions/$today.md"

# Create session directory if needed
if (-not (Test-Path "brain/memory/sessions")) {
    New-Item -ItemType Directory -Force -Path "brain/memory/sessions"
}

# Get today's git changes
$changes = git diff --name-status HEAD 2>$null
$untracked = git ls-files --others --exclude-standard 2>$null
$branch = git branch --show-current 2>$null
$lastCommit = git log -1 --format="%h %s" 2>$null

# Build summary
$lines = @()
$lines += "# Session Log -- $today"
$lines += ""
$lines += "**Generated:** $now"
$lines += "**Branch:** $branch"
$lines += "**Last commit:** $lastCommit"
$lines += ""
$lines += "---"
$lines += ""
$lines += "## Changes This Session"
$lines += ""
$lines += "### Modified Files"

if ($changes) {
    $lines += ""
    foreach ($line in $changes) {
        $parts = $line -split "\t"
        $lines += "- $($parts[0]) $($parts[1])"
    }
} else {
    $lines += ""
    $lines += "_(none)_"
}

$lines += ""
$lines += "### Untracked Files"
if ($untracked) {
    foreach ($f in $untracked) {
        $lines += "- $f"
    }
} else {
    $lines += "_(none)_"
}

$lines += ""
$lines += "---"
$lines += ""
$lines += "## Notes"
$lines += ""
$lines += "_Add your session notes here._"

$summary = $lines -join "`n"

# Write or append
if (Test-Path $sessionFile) {
    $updateLines = @()
    $updateLines += ""
    $updateLines += "---"
    $updateLines += ""
    $updateLines += "## Update -- $timeOnly"
    $updateLines += ""
    $updateLines += "_Summary regenerated._"
    Add-Content -Path $sessionFile -Value ($updateLines -join "`n")
    Write-Host "Updated existing session log: $sessionFile"
} else {
    Set-Content -Path $sessionFile -Value $summary
    Write-Host "Created new session log: $sessionFile"
}

# Also update the index
if (Test-Path "brain/memory/index.json") {
    $indexContent = Get-Content "brain/memory/index.json" -Raw
    $index = $indexContent | ConvertFrom-Json
    $index.last_updated = $today
    $index | ConvertTo-Json -Depth 5 | Set-Content "brain/memory/index.json"
}

Write-Host "Session summary complete."
