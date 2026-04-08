@echo off
title NeuralBox
color 0D

set "ROOT=%~dp0"
set "FLAG=%ROOT%config\.installed"

:: ============================================================
:: NeuralBox - chooses install or launch.
:: config\.installed is written by the installer on success.
:: This file does NO work itself — just routes.
:: ============================================================

if exist "%FLAG%" goto :launch

:: ── First run ─────────────────────────────────────────────────
echo.
echo  First-time setup detected.
echo  Launching installer. You will see a UAC prompt - click Yes.
echo.

:: install.bat handles its own admin elevation via Start-Process RunAs.
call "%ROOT%_engine\install.bat"
exit /b

:: ── Already installed: launch without admin ───────────────────
:launch
color 0A
cls
echo.
echo  ============================================================
echo    NeuralBox  -  Starting...
echo  ============================================================
echo.

call "%ROOT%_engine\launcher\launch-ai.bat"

if errorlevel 1 (
    echo.
    echo  [ERROR] Something went wrong. Check the message above.
    echo  [INFO]  To reinstall: delete config\.installed then run start.bat again.
    echo.
    pause
)
exit /b
