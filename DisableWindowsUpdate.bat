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

set "PS1=%~dp0DisableWindowsUpdate.ps1"
if not exist "%PS1%" (
    echo ERROR: PowerShell script not found:
    echo "%PS1%"
    popd
    pause
    exit /b 2
)

echo.
echo ============================================================
echo   Disable Windows Update
echo ============================================================
echo   [1] Standard   - no SYSTEM Deny ACL / no system DLL rename
echo   [2] Aggressive - includes protected ACL / DLL modification
echo   [Q] Quit
echo.
set /p "MODE=Select mode [1/2/Q]: "

if /I "%MODE%"=="Q" (
    popd
    exit /b 0
)
if "%MODE%"=="2" goto aggressive
if not "%MODE%"=="1" (
    echo Invalid selection.
    popd
    pause
    exit /b 1
)

:standard
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "RC=%errorlevel%"
goto done

:aggressive
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Aggressive
set "RC=%errorlevel%"
goto done

:done
echo.
echo PowerShell exit code: %RC%
popd
pause
exit /b %RC%
