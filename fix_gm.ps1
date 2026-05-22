$file = "autoloads/GameManager.gd"
$lines = Get-Content $file
# Find where the clean function ends (first return base_cap line)
$firstReturn = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "return base_cap\s*$") {
        $firstReturn = $i
        break
    }
}
# Find where _ready starts
$readyLine = -1
for ($i = $firstReturn + 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "func _ready") {
        $readyLine = $i
        break
    }
}
if ($readyLine -eq -1) { Write-Host "ERROR: _ready not found"; exit 1 }
# Build new array: lines up to firstReturn, blank line, then _ready onwards
$newLines = $lines[0..$firstReturn]
$newLines += ""
for ($i = $readyLine; $i -lt $lines.Count; $i++) { $newLines += $lines[$i] }
Set-Content $file $newLines -Encoding UTF8
Write-Host "GameManager cleaned"