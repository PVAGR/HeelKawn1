# Extract GameManager up to new function end, then clean rest
$file = "autoloads/GameManager.gd"
$lines = Get-Content $file

# Find the line after "return base_cap" (first occurrence = correct new function)
$insertIdx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\treturn base_cap$' -and $insertIdx -eq -1) {
        $insertIdx = $i
        break
    }
}
if ($insertIdx -eq -1) { Write-Host "ERROR: could not find first return base_cap"; exit 1 }

# Keep lines 0 through $insertIdx (the new function)
$newLines = $lines[0..$insertIdx]

# Skip lines until "func _ready(" 
for ($i = $insertIdx + 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^$') { continue }
    if ($lines[$i] -match '^\s*var gs: float') { continue }
    if ($lines[$i] -match '^\s*if gs') { continue }
    if ($lines[$i] -match '^\s*return maxi\(') { continue }
    if ($lines[$i] -match '^\s*# Reduced from') { continue }
    # Found a line that matches nothing to skip - add a blank line separator then rest
    $newLines += ""
    $restLines = $lines[$i..($lines.Count-1)]
    $newLines += $restLines
    break
}

Set-Content $file $newLines -Encoding UTF8
Write-Host "Done cleaning"