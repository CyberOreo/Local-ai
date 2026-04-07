@echo off
title NeuralBox - Stopping Services
color 0C

:: ============================================================
:: NeuralBox - STOP SERVICES
:: Stops all services started by launch-ai.bat
:: ============================================================

set "LOG_DIR=%~dp0..\..\logs"
set "LOG_FILE=%LOG_DIR%\launch.log"

echo.
echo  ============================================================
echo    NeuralBox  -  Stopping Services...
echo  ============================================================
echo.

set STOP_ERRORS=0

:: Stop NeuralBox Hub (Node.js process)
echo  Stopping NeuralBox Hub...
taskkill /F /FI "WINDOWTITLE eq LocalAI Hub" >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq NeuralBox Hub" >nul 2>&1
:: Also kill any node process serving port 8080
for /f "tokens=5" %%P in ('netstat -aon 2^>nul ^| findstr /i ":8080 " ^| findstr /i "LISTENING"') do (
    taskkill /F /PID %%P >nul 2>&1
)
echo  [OK]   Hub stopped.

:: Stop Open WebUI container
echo  Stopping Open WebUI container...
docker stop open-webui >nul 2>&1
if errorlevel 1 (
    echo  [INFO] open-webui container was not running (or Docker is not running).
) else (
    echo  [OK]   open-webui stopped.
)

:: Stop Ollama process
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

:: Stop OpenClaw agent
echo  Stopping OpenClaw (Clawbot)...
taskkill /F /FI "WINDOWTITLE eq OpenClaw" >nul 2>&1
taskkill /F /IM openclaw.exe /T >nul 2>&1
echo  [OK]   OpenClaw stopped (if it was running).

echo.
echo  [OK]   Stop sequence complete.
if exist "%LOG_FILE%" (
    echo [%date% %time%] Services stopped >> "%LOG_FILE%"
)
echo.
timeout /t 2 /nobreak >nul
