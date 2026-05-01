# Headless load of the HeelKawn Godot project (parse + short run). Exit code from Godot.
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [int]$QuitAfterFrames = 240
)

$ErrorActionPreference = "Stop"
$godot = & (Join-Path $PSScriptRoot "Resolve-Godot.ps1") -ProjectRoot $ProjectRoot
if ([string]::IsNullOrWhiteSpace($godot)) { exit 1 }

# 240 frames is still fast headless, but lets tick 1 fire so autoload/main
# wiring is exercised instead of only importing the scene tree. Capture Godot
# stderr as data: known engine/runtime warnings should not bypass the strict
# compile gate below as PowerShell NativeCommandError records.
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$output = & $godot --headless --path $ProjectRoot --quit-after $QuitAfterFrames @args 2>&1
$exitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference

foreach ($line in $output) {
    Write-Output $line
}

$compileErrorRegex = '(Parse Error|Failed to load script|with error "Parse error"|SCRIPT ERROR)'
$hasCompileErrors = $false
foreach ($line in $output) {
    if ([string]$line -match $compileErrorRegex) {
        $hasCompileErrors = $true
        break
    }
}

if ($hasCompileErrors) {
    Write-Error "Headless verify failed strict compile gate: script parse/compile errors detected."
    exit 2
}

exit $exitCode
