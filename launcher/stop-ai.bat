@echo off
title Local AI - Stopping Services
color 0C

:: ============================================================
:: LOCAL AI - STOP SERVICES
:: Stops Open WebUI container and Ollama process.
:: ============================================================

set "LOG_DIR=%~dp0..\logs"
set "LOG_FILE=%LOG_DIR%\launch.log"

echo.
echo  ============================================================
echo    LOCAL AI  -  Stopping Services...
echo  ============================================================
echo.

:: Stop Open WebUI container
echo  Stopping Open WebUI container...
docker stop open-webui >nul 2>&1
if errorlevel 1 (
    echo  [INFO] open-webui container was not running (or Docker is not running).
) else (
    echo  [OK]   open-webui stopped.
)

:: Kill Ollama process
echo  Stopping Ollama...
taskkill /F /IM ollama.exe /T >nul 2>&1
if errorlevel 1 (
    echo  [INFO] Ollama was not running.
) else (
    echo  [OK]   Ollama stopped.
)

:: Stop update server (PowerShell window titled LocalAI-UpdateServer)
echo  Stopping update server...
taskkill /F /FI "WINDOWTITLE eq LocalAI-UpdateServer" >nul 2>&1
echo  [OK]   Update server stopped.

echo.
echo  [OK]   All services stopped.
echo [%date% %time%] Services stopped >> "%LOG_FILE%"
echo.
timeout /t 3 /nobreak >nul
