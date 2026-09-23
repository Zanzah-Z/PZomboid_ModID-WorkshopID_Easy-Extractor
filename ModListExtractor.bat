@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "PS1=%SCRIPT_DIR%\ModListExtractor.ps1"

if not exist "%PS1%" (
    echo Could not find ModListExtractor.ps1 next to this .bat file.
    echo Both files need to be in the same folder.
    echo.
    pause
    exit /b 1
)

where powershell >nul 2>nul
if errorlevel 1 (
    where pwsh >nul 2>nul
    if errorlevel 1 (
        echo PowerShell not found - see README.md for the solution, then run this tool again. > "%SCRIPT_DIR%\_SetupCheck.txt"
        echo Neither powershell nor pwsh was found on this system.
        echo See README.md for how to install PowerShell, then run this tool again.
        pause
        exit /b 1
    )
    pwsh -NoProfile -File "%PS1%" -ScriptDir "%SCRIPT_DIR%"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ScriptDir "%SCRIPT_DIR%"
)

echo.
echo ---
echo Finished. Press any key to close this window.
pause >nul
exit /b %errorlevel%
