@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

set "GODOT_EXE=tools\godot\Godot_v4.6.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
  echo [ERROR] Portable Godot not found at %GODOT_EXE%
  echo [INFO] Run: powershell -ExecutionPolicy Bypass -File tools\Download-GodotPortable.ps1
  exit /b 1
)

if not exist ".godot\" (
  echo [INFO] Initializing Godot project cache (.godot)...
  "%GODOT_EXE%" --headless --path "." --quit
  if errorlevel 1 (
    echo [ERROR] Failed to initialize project cache.
    exit /b 1
  )
)

if not exist "logs" mkdir "logs"

set "STAMP=%DATE:~10,4%-%DATE:~4,2%-%DATE:~7,2%_%TIME:~0,2%-%TIME:~3,2%-%TIME:~6,2%"
set "STAMP=%STAMP: =0%"
set "LOG_FILE=logs\playtest_%STAMP%.log"
set "LATEST_FILE=logs\playtest_latest.log"

echo [INFO] Launching HeelKawn with capture...
echo [INFO] Log file: %LOG_FILE%
echo [INFO] (Close game window to finish capture)

"%GODOT_EXE%" --path "." "scenes/main/Main.tscn" > "%LOG_FILE%" 2>&1
set EXIT_CODE=%ERRORLEVEL%

copy /y "%LOG_FILE%" "%LATEST_FILE%" >nul

echo [INFO] Game closed with exit code %EXIT_CODE%.
echo [INFO] Latest log: %LATEST_FILE%
echo [INFO] Timestamped log: %LOG_FILE%
exit /b %EXIT_CODE%
