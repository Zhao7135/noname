@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0Windows\SkyTales.exe" (
    start "" "%~dp0Windows\SkyTales.exe"
    exit /b
)
if exist "D:\Godot\Godot_v4.7.2-stable_win64.exe" (
    start "" "D:\Godot\Godot_v4.7.2-stable_win64.exe" --path "%CD%"
    exit /b
)
where godot.exe >nul 2>nul
if not errorlevel 1 (
    start "" godot.exe --path "%CD%"
    exit /b
)
echo Please open project.godot with Godot 4.4 or later.
pause
