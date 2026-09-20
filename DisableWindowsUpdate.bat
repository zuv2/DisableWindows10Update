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
echo   Disable Windows Update
echo ============================================================
echo   [1] Standard   - no SYSTEM Deny ACL / no system DLL rename
echo   [2] Aggressive - includes protected ACL / DLL modification
echo   [Q] Quit
echo.
set /p MODE=Select mode [1/2/Q]: 

if /I "%MODE%"=="Q" exit /b 0
if "%MODE%"=="2" goto aggressive
if not "%MODE%"=="1" (
    echo Invalid selection.
    pause
    exit /b 1
)

:standard
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\DisableWindowsUpdate.ps1"
set "RC=%errorlevel%"
goto done

:aggressive
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\DisableWindowsUpdate.ps1" -Aggressive
set "RC=%errorlevel%"
goto done

:done
echo.
echo PowerShell exit code: %RC%
pause
exit /b %RC%
