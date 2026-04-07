@echo off
title NeuralBox Hub
color 0D

echo.
echo  Starting NeuralBox Hub...

:: Check Node.js
where node >nul 2>&1
if errorlevel 1 (
    if exist "%ProgramFiles%\nodejs\node.exe" (
        set "PATH=%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"
    ) else (
        echo.
        echo  [ERROR] Node.js not found. Please run install-openclaw.bat first.
        echo.
        pause
        exit /b 1
    )
)

:: Start hub server
start "NeuralBox Hub" /min node "%~dp0hub.js"

echo  [INFO] Waiting for hub to start...
timeout /t 2 /nobreak >nul

:: Open browser
start http://localhost:8080

echo  [OK]   NeuralBox Hub opened in your browser.
echo.
echo  The hub window runs minimised in the background.
echo  Close this window - the hub keeps running.
echo.
timeout /t 3 /nobreak >nul
