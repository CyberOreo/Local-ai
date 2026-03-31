@echo off
setlocal EnableDelayedExpansion
title Local AI

:: ============================================================
::
::   LOCAL AI - START
::   Double-click this file to install OR launch.
::
::   First time?  -> Installs everything automatically.
::   Already set up? -> Starts the AI and opens your browser.
::
:: ============================================================

set "ROOT=%~dp0"
set "FLAG=%ROOT%config\.installed"

:: ---- Elevate to Administrator if needed ---------------------
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator access...
    powershell -Command "Start-Process cmd.exe -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

echo  [OK] Running as Administrator.
echo  [INFO] Root folder: %ROOT%
echo  [INFO] Flag file: %FLAG%
if exist "%FLAG%" (
    echo  [INFO] .installed flag found - launching...
) else (
    echo  [INFO] .installed flag NOT found - running installer...
)
echo.

:: ---- First time: run installer ------------------------------
if not exist "%FLAG%" (
    cls
    color 0B
    echo.
    echo  ============================================================
    echo    LOCAL AI  -  FIRST TIME SETUP
    echo  ============================================================
    echo.
    echo  Welcome! This will set up your local AI automatically.
    echo.
    echo  What happens next:
    echo    1. Ollama (AI runtime) will be downloaded and installed
    echo    2. The Qwen 3.5 9B model (~6.6 GB) will be downloaded
    echo    3. A backup model (~2.5 GB) will also be downloaded
    echo    4. The chat interface will be configured
    echo    5. Your browser will open automatically when ready
    echo.
    echo  BEFORE YOU CONTINUE:
    echo    Make sure Docker Desktop is installed and running.
    echo    (Look for the whale icon in your system tray)
    echo.
    echo    Don't have Docker Desktop?
    echo    Download it from: https://www.docker.com/products/docker-desktop/
    echo    Install it, start it, then come back and press any key.
    echo.
    pause
    cls
    powershell -ExecutionPolicy Bypass -File "%ROOT%install.ps1" -ProjectRoot "%ROOT%"
    exit /b
)

:: ---- Already installed: just launch -------------------------
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
    echo  [ERROR] Launch failed. See message above.
    echo.
    pause
)
