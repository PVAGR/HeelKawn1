# Automated Android SDK + JDK Setup for Godot 4.x
# Run this script in PowerShell

$ErrorActionPreference = "Continue"

Write-Host "=== Android SDK + JDK Auto-Setup for Godot ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Download and Install JDK 17
Write-Host "[1/5] Installing JDK 17..." -ForegroundColor Yellow

# Check for existing JDK
$existingJava = Get-Command java -ErrorAction SilentlyContinue
if ($existingJava) {
    Write-Host "Java already installed: $($existingJava.Source)" -ForegroundColor Green
    $jdkPath = (Get-Command java).Source -replace "\\bin\\java.exe$", ""
    if ($jdkPath.EndsWith("\bin")) { $jdkPath = $jdkPath.Substring(0, $jdkPath.Length - 5) }
} else {
    Write-Host "Downloading JDK 17..." -ForegroundColor Cyan
    
    $jdkUrl = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.14%2B7/OpenJDK17U-jdk_x64_windows_hotspot_17.0.14_7.msi"
    $jdkInstaller = "$env:TEMP\jdk17-installer.msi"
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $jdkUrl -OutFile $jdkInstaller -UseBasicParsing
        Write-Host "Installing JDK 17 (this may take a minute)..." -ForegroundColor Cyan
        Start-Process msiexec.exe -ArgumentList "/i `"$jdkInstaller`" /quiet /norestart" -Wait -NoNewWindow
        Write-Host "JDK 17 installed" -ForegroundColor Green
        
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        $jdkPath = "C:\Program Files\Eclipse Adoptium\jdk-17.0.14.7-hotspot"
        if (-not (Test-Path $jdkPath)) {
            $jdkPath = (Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Directory | Select-Object -First 1).FullName
        }
    } catch {
        Write-Host "ERROR: Failed to install JDK. Please install manually:" -ForegroundColor Red
        Write-Host "https://adoptium.net/temurin/releases/?version=17&arch=x64&os=windows" -ForegroundColor Cyan
        exit
    }
}

# Step 2: Create Android SDK directory
$sdkRoot = "C:\Android"
if (Test-Path $sdkRoot) {
    Write-Host "`n[2/5] Android SDK directory exists at $sdkRoot" -ForegroundColor Green
} else {
    Write-Host "`n[2/5] Creating Android SDK directory..." -ForegroundColor Yellow
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
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
        
        Write-Host "Extracting..." -ForegroundColor Cyan
        if (Test-Path $cmdToolsDir) { Remove-Item -Recurse -Force $cmdToolsDir }
        New-Item -ItemType Directory -Path "$cmdToolsDir\temp" -Force | Out-Null
        Expand-Archive -Path $zipPath -DestinationPath "$cmdToolsDir\temp" -Force
        
        Move-Item -Path "$cmdToolsDir\temp\cmdline-tools" -Destination "$cmdToolsDir\cmdline-tools" -Force
        Remove-Item -Path "$cmdToolsDir\temp" -Recurse -Force
        Remove-Item -Path $zipPath -Force
        
        Write-Host "Command Line Tools installed" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to download SDK tools: $_" -ForegroundColor Red
        exit
    }
}

# Step 4: Accept licenses and install components
Write-Host "`n[4/5] Installing SDK components (build-tools, platform-tools, platform)..." -ForegroundColor Yellow

$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot

# Auto-accept licenses
$yes = "y`n" * 10
$yes | & "$cmdToolsDir\cmdline-tools\bin\sdkmanager.bat" --sdk_root=$sdkRoot --licenses 2>&1 | Out-Null

# Install components
& "$cmdToolsDir\cmdline-tools\bin\sdkmanager.bat" --sdk_root=$sdkRoot "build-tools;34.0.0" "platform-tools" "platforms;android-34" 2>&1 | ForEach-Object { Write-Host "  $_" }

Write-Host "SDK components installed" -ForegroundColor Green

# Step 5: Summary
Write-Host "`n=== Setup Complete! ===" -ForegroundColor Green
Write-Host "`nOpen Godot and set these paths:" -ForegroundColor Cyan
Write-Host "  Editor Settings -> Export -> Android" -ForegroundColor White
Write-Host "  Android SDK Path: $sdkRoot" -ForegroundColor Yellow
Write-Host "  Java SDK Path:    $jdkPath" -ForegroundColor Yellow

Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
