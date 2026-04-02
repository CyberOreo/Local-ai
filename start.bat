@echo off
title NeuralBox
color 0D

set "ROOT=%~dp0"
set "FLAG=%ROOT%config\.installed"

:: ============================================================
:: Detect whether this is a first-time install or a launch.
:: Check BOTH the flag file AND whether Ollama is installed.
:: (The flag file is gitignored so it won't exist after a fresh
::  git pull even if Ollama/Docker are already set up.)
:: ============================================================

set "ALREADY_INSTALLED=0"
if exist "%FLAG%" set "ALREADY_INSTALLED=1"

:: Also check if Ollama is actually installed on this machine
if "%ALREADY_INSTALLED%"=="0" (
    where ollama >nul 2>&1
    if not errorlevel 1 set "ALREADY_INSTALLED=1"
)

:: Also check if the open-webui Docker container exists
if "%ALREADY_INSTALLED%"=="0" (
    docker ps -a --filter "name=^open-webui$" --format "{{.Names}}" 2>nul | findstr /i "open-webui" >nul 2>&1
    if not errorlevel 1 set "ALREADY_INSTALLED=1"
)

if "%ALREADY_INSTALLED%"=="0" (
    echo.
    echo  First-time setup detected. Running installer...
    echo  Requesting administrator access...
    echo.
    powershell -Command "Start-Process cmd.exe -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

:: Create the flag file so future launches are instant
if not exist "%FLAG%" (
    if not exist "%ROOT%config" mkdir "%ROOT%config"
    echo installed > "%FLAG%"
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

call "%ROOT%_engine\launcher\launch-ai.bat"

if errorlevel 1 (
    echo.
    echo  [ERROR] Something went wrong. Read the message above.
    echo.
)

echo  Press any key to close this window.
echo  (All services keep running in the background)
pause >nul
