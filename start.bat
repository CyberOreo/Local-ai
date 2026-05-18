@echo off
title NeuralBox
color 0D
setlocal

:: %~dp0 ends with \  — strip it so "path\" never breaks PowerShell argument parsing
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "FLAG=%ROOT%\config\.installed"

if exist "%FLAG%" goto :launch

:: ── First run: install ────────────────────────────────────────────────────────
cls
echo.
echo  ============================================================
echo    NeuralBox  -  First-time Setup
echo  ============================================================
echo.
echo  Installing Ollama, AI model, and Open WebUI.
echo  A UAC prompt will appear - click YES.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\_engine\install.ps1" -ProjectRoot "%ROOT%"

if exist "%FLAG%" (
    echo.
    echo  [OK]  Setup complete. Starting NeuralBox...
    timeout /t 2 /nobreak >nul
    goto :launch
)

echo.
echo  [!]  Setup did not finish.
echo       Check logs\install.log for details.
echo       Close this window and run start.bat again to retry.
echo.
pause
exit /b 1

:: ── Already installed: launch ─────────────────────────────────────────────────
:launch
color 0A
cls
call "%ROOT%\_engine\launcher\launch-ai.bat"
if errorlevel 1 (
    echo.
    echo  [ERROR]  Launch failed. See messages above.
    echo  To reinstall: delete config\.installed and run start.bat.
    echo.
    pause
)
exit /b
