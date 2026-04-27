# Creator verification helper: runs project parse/smoke then prints milestone checklist.
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

Write-Host "HeelKawn creator verification"
Write-Host "- See docs/TIME_SCALE.md for tick/year/wall-clock mapping."
Write-Host "- Kernel one-shot diagnostic tick: SimTime.KERNEL_DIAGNOSTIC_TICK (= in-world year length, 30000 ticks)."
Write-Host "- Automated parse/headless smoke:"
& (Join-Path $PSScriptRoot "Verify-Project.ps1") -ProjectRoot $ProjectRoot @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Manual long-run checklist (Creator):"
Write-Host "  [ ] Run to tick 30000+ at 1x without forced pause for cool-down."
Write-Host "  [ ] At KERNEL DIAGNOSTIC: settlements + wildlife counts plausible; export_ready dev/public lines present."
Write-Host "  [ ] Burst 100x: UI may hitch; divergence per-claim logs off at 26x+."
Write-Host "  [ ] Pawn panel: Profession 'not locked' explains action-skill tracks before first lock."
