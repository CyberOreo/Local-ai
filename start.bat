@echo off
title NeuralBox
color 0D

set "ROOT=%~dp0"
set "FLAG=%ROOT%config\.installed"

:: ============================================================
:: Detect whether this is a first-time install or a normal launch.
:: Checks: flag file, Ollama installed, Docker installed, container exists.
:: ============================================================

set "ALREADY_INSTALLED=0"

:: Check 1: flag file
if exist "%FLAG%" set "ALREADY_INSTALLED=1"

:: Check 2: Ollama binary on PATH
if "%ALREADY_INSTALLED%"=="0" (
    where ollama >nul 2>&1
    if not errorlevel 1 (
        :: Also need Docker to consider installed
        where docker >nul 2>&1
        if not errorlevel 1 (
            :: Also need container to exist
            docker ps -a --filter "name=^open-webui$" --format "{{.Names}}" 2>nul | findstr /i "open-webui" >nul 2>&1
            if not errorlevel 1 set "ALREADY_INSTALLED=1"
        )
    )
)

if "%ALREADY_INSTALLED%"=="0" (
    echo.
    echo  First-time setup detected. Launching installer...
    echo  The installer requires administrator access.
    echo.
    powershell -Command "Start-Process cmd.exe -ArgumentList '/c \"%~dp0_engine\install.bat\"' -Verb RunAs"
    exit /b
)

:: Write flag file for future fast detection
if not exist "%FLAG%" (
    if not exist "%ROOT%config" mkdir "%ROOT%config"
    echo installed > "%FLAG%"
)

:: ---- Already installed: launch WITHOUT admin elevation -------
cls
color 0A
echo.
echo  ============================================================
echo    NeuralBox  -  Starting...
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
