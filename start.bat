@echo off
title NeuralBox
color 0D
setlocal

set "ROOT=%~dp0"
set "FLAG=%ROOT%config\.installed"

if exist "%FLAG%" goto :launch

:: ── First run: install ────────────────────────────────────────────────────────
cls
echo.
echo  NeuralBox - First time setup
echo  A UAC prompt will appear - click YES.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%_engine\install.ps1" -ProjectRoot "%ROOT%"

if exist "%FLAG%" (
    echo.
    echo  Starting NeuralBox...
    timeout /t 2 /nobreak >nul
    goto :launch
)
echo.
echo  Setup did not complete. Check logs\install.log, then run start.bat again.
echo.
pause
exit /b 1

:: ── Already installed: launch ─────────────────────────────────────────────────
:launch
color 0A
cls
call "%ROOT%_engine\launcher\launch-ai.bat"
if errorlevel 1 (
    echo.
    echo  Something went wrong. See the messages above.
    echo  To reinstall: delete config\.installed then run start.bat.
    echo.
    pause
)
exit /b
