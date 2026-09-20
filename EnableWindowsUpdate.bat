@echo off
setlocal EnableExtensions

rem Always run relative to this BAT file. Keep this launcher ASCII-only.
pushd "%~dp0" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Cannot access script directory:
    echo "%~dp0"
    pause
    exit /b 1
)

rem Elevate through UAC if required.
fltmc >nul 2>&1
if errorlevel 1 (
    echo Requesting administrator privileges...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:ComSpec -ArgumentList '/d','/c','\"\"%~f0\"\"' -WorkingDirectory '\"\"%~dp0\"\"' -Verb RunAs"
    popd
    exit /b
)

set "PS1=%~dp0EnableWindowsUpdate.ps1"
if not exist "%PS1%" (
    echo ERROR: PowerShell script not found:
    echo "%PS1%"
    popd
    pause
    exit /b 2
)

echo.
echo ============================================================
echo   Enable Windows Update
echo   Restore reversible settings from Disable script
echo ============================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "RC=%errorlevel%"

echo.
echo PowerShell exit code: %RC%
popd
pause
exit /b %RC%
