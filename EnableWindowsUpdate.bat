@echo off
setlocal
cd /d "%~dp0"

:: 관리자 권한이 아니면 UAC 승격
net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Requesting administrator privileges...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo ============================================================
echo   Enable Windows Update
echo   Restore reversible settings from Disable V4.x
echo ============================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\EnableWindowsUpdate.ps1"
set "RC=%errorlevel%"

echo.
echo PowerShell exit code: %RC%
pause
exit /b %RC%
