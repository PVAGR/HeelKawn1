@echo off
setlocal

cd /d "%~dp0"

where godot >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Godot executable not found in PATH.
  call "%~dp0check_godot_path.bat"
  exit /b 1
)

if not exist ".godot\" (
  echo [INFO] Initializing Godot project cache (.godot)...
  godot --headless --path "." --quit
  if errorlevel 1 (
    echo [ERROR] Failed to initialize project cache.
    exit /b 1
  )
)

echo [INFO] Launching HeelKawn simulation worker...
godot --headless --path "." -- --simulation-worker
set EXIT_CODE=%ERRORLEVEL%
echo [INFO] Worker closed with exit code %EXIT_CODE%.
exit /b %EXIT_CODE%