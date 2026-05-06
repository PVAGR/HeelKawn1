<# HeelKawn UI Stability Test Runner (Preview) #>
<# This is a lightweight launcher for Godot UI tests. It does not assume Godot is installed in a fixed path. It will attempt to discover a godot executable and provide the commands you can run. >

Param()

$projectRoot = Resolve-Path ".." | % { $_.Path }

Write-Host "[UI Tests] Project root: $projectRoot"

$godotCmd = Get-Command godot -ErrorAction SilentlyContinue
if ($null -eq $godotCmd) {
    $possible = @(
        "$env:ProgramFiles\Godot Godot.exe",
        "$env:PROGRAMFILES(X86)\\Godot\\godot.exe",
        "$projectRoot\godot.exe"
    )
    foreach ($p in $possible) {
        if (Test-Path "$p") { $godotCmd = $p; break }
    }
}

if ($null -eq $godotCmd) {
    Write-Host "[UI Tests] Godot executable not found. Please install Godot or adjust PATH." -ForegroundColor Red
    exit 1
}

Write-Host "[UI Tests] Using Godot executable: $godotCmd" -ForegroundColor Green

# Define test scenes (these are the targets for validation)
$scenes = @(
    "scenes/ui/SurvivalHUD.tscn",
    "scenes/ui/PlayerInventoryUI.tscn",
    "scenes/ui/PawnMoodUI.tscn"
)

foreach ($scene in $scenes) {
    $cmd = `& "$godotCmd" --headless --path `"$projectRoot`" --scene `"$scene`"`
    Write-Host "[UI Tests] Would run: $cmd"
}

Write-Host "[UI Tests] End of dry-run. Copy the commands above and execute in your environment to perform actual tests." -ForegroundColor Yellow
