@echo off
setlocal

where godot >nul 2>&1
if not errorlevel 1 (
  echo [OK] Godot found in PATH.
  for /f "delims=" %%i in ('where godot') do echo  - %%i
  exit /b 0
)

echo [ERROR] Godot was not found in your system PATH.
echo.
echo Add Godot 4 to PATH (Windows):
echo 1. Locate your Godot executable folder, e.g.:
echo    C:\Tools\Godot\
echo 2. Press Win + R, type: sysdm.cpl , press Enter.
echo 3. Open Advanced ^> Environment Variables.
echo 4. Under System variables, edit Path.
echo 5. Click New and add the Godot folder path.
echo 6. Click OK on all dialogs.
echo 7. Close and reopen terminal/Explorer, then re-run:
echo    .\play.bat
echo.
exit /b 1
