# Automated Android SDK Setup for Godot 4.x
# Run this script in PowerShell (as Administrator recommended)

$ErrorActionPreference = "Stop"

Write-Host "=== Android SDK Auto-Setup for Godot ===" -ForegroundColor Cyan

# Step 1: Check for JDK
Write-Host "`n[1/5] Checking for JDK 17..." -ForegroundColor Yellow
$javaPath = Get-Command java -ErrorAction SilentlyContinue
if ($javaPath) {
    $javaVersion = java -version 2>&1 | Select-String "version"
    Write-Host "Found Java: $javaVersion" -ForegroundColor Green
} else {
    Write-Host "JDK 17 not found. Downloading..." -ForegroundColor Red
    Write-Host "Please download and install JDK 17 from:" -ForegroundColor Yellow
    Write-Host "https://adoptium.net/temurin/releases/?version=17&arch=x64&os=windows" -ForegroundColor Cyan
    Write-Host "After installation, re-run this script." -ForegroundColor Yellow
    exit
}

# Step 2: Create Android SDK directory
$sdkRoot = "C:\Android"
if (Test-Path $sdkRoot) {
    Write-Host "`n[2/5] Android SDK directory already exists at $sdkRoot" -ForegroundColor Green
} else {
    Write-Host "`n[2/5] Creating Android SDK directory at $sdkRoot..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $sdkRoot -Force | Out-Null
    Write-Host "Created $sdkRoot" -ForegroundColor Green
}

# Step 3: Download Android Command Line Tools
$cmdToolsDir = "$sdkRoot\cmdline-tools"
$cmdToolsBin = "$cmdToolsDir\cmdline-tools\bin\sdkmanager.bat"

if (Test-Path $cmdToolsBin) {
    Write-Host "`n[3/5] Android Command Line Tools already installed" -ForegroundColor Green
} else {
    Write-Host "`n[3/5] Downloading Android Command Line Tools..." -ForegroundColor Yellow
    
    $downloadUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
    $zipPath = "$env:TEMP\android-cmdline-tools.zip"
    
    Write-Host "Downloading from Google..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
    
    Write-Host "Extracting..." -ForegroundColor Cyan
    if (Test-Path $cmdToolsDir) {
        Remove-Item -Recurse -Force $cmdToolsDir
    }
    New-Item -ItemType Directory -Path $cmdToolsDir -Force | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath "$cmdToolsDir\temp" -Force
    
    # Move contents to correct location
    Move-Item -Path "$cmdToolsDir\temp\cmdline-tools" -Destination "$cmdToolsDir\cmdline-tools" -Force
    Remove-Item -Path "$cmdToolsDir\temp" -Recurse -Force
    Remove-Item -Path $zipPath -Force
    
    Write-Host "Command Line Tools installed" -ForegroundColor Green
}

# Step 4: Accept licenses and install components
Write-Host "`n[4/5] Accepting licenses and installing SDK components..." -ForegroundColor Yellow

$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot

# Accept licenses
Write-Host "Accepting SDK licenses..." -ForegroundColor Cyan
& "$cmdToolsDir\cmdline-tools\bin\sdkmanager.bat" --sdk_root=$sdkRoot --licenses 2>&1 | ForEach-Object { Write-Host $_ }

# Install required components
Write-Host "`nInstalling build-tools, platform-tools, and platform..." -ForegroundColor Cyan
& "$cmdToolsDir\cmdline-tools\bin\sdkmanager.bat" --sdk_root=$sdkRoot "build-tools;34.0.0" "platform-tools" "platforms;android-34" 2>&1 | ForEach-Object { Write-Host $_ }

Write-Host "SDK components installed" -ForegroundColor Green

# Step 5: Configure Godot Editor Settings
Write-Host "`n[5/5] Configuring Godot..." -ForegroundColor Yellow

# Find JDK path
$jdkPath = (Get-Command java).Source -replace "\\bin\\java.exe$", ""
# Clean up path (remove trailing \bin if present)
if ($jdkPath.EndsWith("\bin")) {
    $jdkPath = $jdkPath.Substring(0, $jdkPath.Length - 5)
}

Write-Host "`n=== Setup Complete! ===" -ForegroundColor Green
Write-Host "`nConfigure Godot Editor Settings with these paths:" -ForegroundColor Cyan
Write-Host "  Android SDK Path: $sdkRoot" -ForegroundColor White
Write-Host "  Java SDK Path:    $jdkPath" -ForegroundColor White

Write-Host "`nTo configure in Godot:" -ForegroundColor Yellow
Write-Host "  1. Open Godot Editor" -ForegroundColor White
Write-Host "  2. Editor -> Editor Settings" -ForegroundColor White
Write-Host "  3. Scroll to Export -> Android" -ForegroundColor White
Write-Host "  4. Set the paths above" -ForegroundColor White

Write-Host "`nThen install Export Templates:" -ForegroundColor Yellow
Write-Host "  1. Project -> Export" -ForegroundColor White
Write-Host "  2. Manage Export Templates -> Download and Install" -ForegroundColor White

Write-Host "`nDone! You can now export APKs for Android." -ForegroundColor Green
