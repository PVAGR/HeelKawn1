# Returns absolute path to Godot 4.x executable for HeelKawn CI / agent checks.
# Order: HEELKAWN_GODOT, repo tools/godot/*.exe, PATH (godot_console / godot)
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

if ($env:HEELKAWN_GODOT -and (Test-Path -LiteralPath $env:HEELKAWN_GODOT)) {
    return (Resolve-Path -LiteralPath $env:HEELKAWN_GODOT).Path
}

$toolsGodot = Join-Path $ProjectRoot "tools\godot"
if (Test-Path $toolsGodot) {
    $portable = Get-ChildItem -Path $toolsGodot -Filter "Godot_v*_console.exe" -File -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($portable) { return $portable.FullName }
    $portable = Get-ChildItem -Path $toolsGodot -Filter "Godot_v*.exe" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike "*_console*" } |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($portable) { return $portable.FullName }
}

$cmd = Get-Command godot_console -ErrorAction SilentlyContinue
if (-not $cmd) { $cmd = Get-Command godot -ErrorAction SilentlyContinue }
if ($cmd) { return $cmd.Source }

Write-Error "Godot not found. Set HEELKAWN_GODOT, install via winget (GodotEngine.GodotEngine), or run tools/Download-GodotPortable.ps1"
exit 1
