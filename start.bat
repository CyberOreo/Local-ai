@echo off
title Local AI
color 0A

set "ROOT=%~dp0"
set "FLAG=%ROOT%config\.installed"

:: ============================================================
:: First time? Run the installer (needs admin).
:: Already installed? Launch directly — NO admin needed.
:: ============================================================

if not exist "%FLAG%" (
    echo.
    echo  First-time setup detected.
    echo  Requesting administrator access for the installer...
    echo.
    powershell -Command "Start-Process cmd.exe -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

:: ---- Already installed: launch WITHOUT admin elevation -------
:: (Admin elevation breaks Docker path detection - do NOT elevate here)

cls
color 0A
echo.
echo  ============================================================
echo    LOCAL AI  -  Starting...
echo  ============================================================
echo.

call "%ROOT%launcher\launch-ai.bat"

if errorlevel 1 (
    echo.
    echo  [ERROR] Something went wrong. Read the message above.
    echo.
)

echo  Press any key to close this window.
echo  (All services keep running in the background)
pause >nul
