# Fix GameManager.gd: remove duplicate dead code after new adaptive_frame_tick_cap function
param(
    [string]$FilePath = "autoloads/GameManager.gd"
)

$lines = Get-Content $FilePath
$output = @()

$inDeadCode = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    
    # Start of dead code: "var gs: float" after first "return base_cap"
    if ($line -match '^\s*var gs: float') {
        $inDeadCode = $true
    }
    
    if ($inDeadCode) {
        # End of dead code: blank line after second "return base_cap"
        if ($line -match '^\s*return base_cap') {
            # Check next line is blank
            if ($i + 1 -lt $lines.Count -and $lines[$i+1] -match '^\s*$') {
                $i += 1  # skip the blank line too
                $inDeadCode = $false
                continue
            }
        }
        continue  # skip this line (dead code)
    }
    
    $output += $line
}

Set-Content $FilePath $output -Encoding UTF8
Write-Host "GameManager.gd cleaned successfully"