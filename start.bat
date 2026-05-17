@echo off
title NeuralBox
color 0D
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1

set "ROOT=%~dp0"
set "FLAG=%ROOT%config\.installed"

:: ── First run: install ────────────────────────────────────────────────────────
if exist "%FLAG%" goto :launch

cls
echo.
echo  ============================================================
echo    NeuralBox  -  First-time Setup
echo  ============================================================
echo.
echo  Installing Ollama, AI model, and Open WebUI.
echo  A UAC prompt will appear - click YES to allow it.
echo.
echo  This window will wait for the installer to finish.
echo.

powershell -NoProfile -Command ^
  "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%ROOT%_engine\install.ps1"" -ProjectRoot ""%ROOT%""'"

if exist "%FLAG%" (
    echo.
    echo  [OK]  Installation complete. Starting NeuralBox...
    timeout /t 2 /nobreak >nul
    goto :launch
)

echo.
echo  [!]  Setup did not finish. Check logs\install.log for details.
echo       Run this file again to retry.
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
    echo  [ERROR]  Something went wrong. See messages above.
    echo  [TIP]    Delete config\.installed and run start.bat again to reinstall.
    echo.
    pause
)
exit /b
