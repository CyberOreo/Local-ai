@echo off
title NeuralBox Setup
color 0D
chcp 65001 >nul 2>&1

cls
echo.
echo.
echo   =====================================================
echo.
echo      888b    888                            888
echo      8888b   888                            888
echo      88888b  888                            888
echo      888Y88b 888  .d88b.  888  888 888d888 8888b.   .d88b.  888  888
echo      888 Y88b888 d8P  Y8b 888  888 888P"      "88b d88""88b `Y8bd8P'
echo      888  Y88888 88888888 888  888 888    .d888888 888  888   X88K
echo      888   Y8888 Y8b.     Y88b 888 888    888  888 Y88..88P .d8""8b.
echo      888    Y888  "Y8888   "Y88888 888    "Y888888  "Y88P"  888  888
echo.
echo   =====================================================
echo         Your Private AI Empire  --  Version 1.0
echo   =====================================================
echo.
echo.
echo   Welcome! This will install and launch NeuralBox.
echo.
echo   What happens next:
echo     [1] Checks your PC (RAM, disk, GPU)
echo     [2] Installs Ollama (AI engine) if needed
echo     [3] Downloads the AI model  (~5 GB, one-time only)
echo     [4] Sets up Open WebUI in Docker
echo     [5] Opens NeuralBox in your browser
echo.
echo   Requirements:
echo     - Windows 10 / 11
echo     - 12 GB RAM minimum
echo     - 25 GB free disk space
echo     - Docker Desktop installed (docker.com/products/docker-desktop)
echo.
echo   Time to install: about 10-20 minutes (first time only)
echo   After that: starts in under 30 seconds every time.
echo.
echo   =====================================================
echo.

set /p READY="   Press ENTER to start install, or close this window to cancel: "

echo.
echo   Starting NeuralBox setup...
echo.

:: Hand off to main start.bat
call "%~dp0start.bat"
