@echo off
echo ========================================
echo HeelKawn System Verification Script
echo ========================================
echo.

echo [1/5] Checking Godot executable...
if exist "tools\godot\Godot_v4.6.2-stable_win64.exe" (
    echo ✅ Godot 4.6.2 found
) else (
    echo ❌ Godot executable not found
    echo Please ensure Godot 4.6.2 is in tools\godot\ folder
    pause
    exit /b 1
)

echo.
echo [2/5] Checking project files...
if exist "project.godot" (
    echo ✅ project.godot found
) else (
    echo ❌ project.godot not found
    pause
    exit /b 1
)

if exist "scenes\main\Main.tscn" (
    echo ✅ Main scene found
) else (
    echo ❌ Main scene not found
    pause
    exit /b 1
)

echo.
echo [3/5] Checking autoload scripts...
set "autoloads_ok=1"
if exist "autoloads\ObservationAPI.gd" (
    echo ✅ ObservationAPI.gd found
) else (
    echo ❌ ObservationAPI.gd not found
    set "autoloads_ok=0"
)

if exist "autoloads\CommandAPI.gd" (
    echo ✅ CommandAPI.gd found
) else (
    echo ❌ CommandAPI.gd not found
    set "autoloads_ok=0"
)

if exist "autoloads\AIAgentManager.gd" (
    echo ✅ AIAgentManager.gd found
) else (
    echo ❌ AIAgentManager.gd not found
    set "autoloads_ok=0"
)

if "%autoloads_ok%"=="0" (
    echo.
    echo ❌ Critical autoload files missing
    pause
    exit /b 1
)

echo.
echo [4/5] Checking AI Agent files...
if exist "scripts\ai\AIAgent.gd" (
    echo ✅ AIAgent.gd found
) else (
    echo ❌ AIAgent.gd not found
    pause
    exit /b 1
)

if exist "scripts\ui\AIAgentDebugPanel.gd" (
    echo ✅ AIAgentDebugPanel.gd found
) else (
    echo ❌ AIAgentDebugPanel.gd not found
    pause
    exit /b 1
)

echo.
echo [5/5] Launching system test...
echo.
echo Watch for these success indicators:
echo - [INFO] PawnSpawner: pawn_scene loaded successfully
echo - [DayNight] Day 1 begins (tick 1)
echo - AI Agent Debug Panel shows 8 agents
echo - Press M to toggle Map Mode overlay
echo.
echo Press Ctrl+C to stop the test
echo.

"tools\godot\Godot_v4.6.2-stable_win64.exe" --path "." "scenes/main/Main.tscn" 2>&1 | tee logs\system_verification.log

echo.
echo ========================================
echo Test completed. Check logs\system_verification.log
echo ========================================
pause
