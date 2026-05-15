@echo off
setlocal

cd /d "%~dp0"

where godot >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Godot executable not found in PATH.
  call "%~dp0check_godot_path.bat"
  exit /b 1
)

if not exist "export\" (
  mkdir "export"
)

echo [INFO] Exporting HeelKawn executable...
godot --headless --path "." --export-debug "Windows Desktop" "export/HeelKawn.exe"
if errorlevel 1 (
  echo [ERROR] Export failed.
  exit /b 1
)

echo [SUCCESS] Export complete: "%cd%\export\HeelKawn.exe"
exit /b 0
