@echo off
setlocal
cd /d "%~dp0"
set "GODOT_EXE="
if exist "tools\godot\Godot_v4.6.2-stable_win64.exe" set "GODOT_EXE=tools\godot\Godot_v4.6.2-stable_win64.exe"
if "%GODOT_EXE%"=="" where godot >nul 2>&1 && set "GODOT_EXE=godot"
if "%GODOT_EXE%"=="" ( echo [ERROR] Godot not found. & pause & exit /b 1 )
if not exist ".godot\" "%GODOT_EXE%" --headless --path "." --quit
if not exist "logs" mkdir "logs"
set "LOG=logs\fast_test_latest.log"
echo [INFO] Launching at 200x speed. Pass seconds as argument to auto-close: play_test_fast.bat 120
if not "%~1"=="" (
    start /b "" "%GODOT_EXE%" --path "." "scenes/main/Main.tscn" --test-fast-mode > "%LOG%" 2>&1
    ping -n %~1 127.0.0.1 > nul
    taskkill /im Godot_v4.6.2-stable_win64.exe /f > nul 2>&1
    taskkill /im godot.exe /f > nul 2>&1
    echo [INFO] Closed after %~1 seconds.
) else (
    "%GODOT_EXE%" --path "." "scenes/main/Main.tscn" --test-fast-mode > "%LOG%" 2>&1
)
echo [INFO] Log: %LOG%
powershell -Command "Get-Content '%LOG%' -Tail 30"
pause
