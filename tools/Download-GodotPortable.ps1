# Downloads Godot 4.6.2 Windows portable (matches docs/HEELKAWN_STATE.md) into tools/godot/.
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$Version = "4.6.2"
)

$ErrorActionPreference = "Stop"
$dest = Join-Path $ProjectRoot "tools\godot"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$zipName = "Godot_v${Version}-stable_win64.exe.zip"
$url = "https://github.com/godotengine/godot/releases/download/${Version}-stable/$zipName"
$zip = Join-Path $env:TEMP $zipName
Write-Host "Downloading $url"
Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
Expand-Archive -Path $zip -DestinationPath $dest -Force
Write-Host "Extracted to $dest"
Get-ChildItem $dest -Filter "Godot*.exe"
