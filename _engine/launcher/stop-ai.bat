@echo off
setlocal EnableDelayedExpansion
title NeuralBox - Stopping Services
color 0C

:: ============================================================
:: NeuralBox - STOP SERVICES
:: Stops everything started by launch-ai.bat and verifies each.
:: ============================================================

set "LOG_DIR=%~dp0..\..\logs"
set "LOG_FILE=%LOG_DIR%\launch.log"

echo.
echo  ============================================================
echo    NeuralBox  -  Stopping Services...
echo  ============================================================
echo.

set STOP_ERRORS=0

:: ── NeuralBox Hub (Node.js on port 8080) ─────────────────────
echo  Stopping NeuralBox Hub...
taskkill /F /FI "WINDOWTITLE eq LocalAI Hub"   >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq NeuralBox Hub" >nul 2>&1
:: Kill any node process that holds port 8080
for /f "tokens=5" %%P in ('netstat -aon 2^>nul ^| findstr /i ":8080 " ^| findstr /i "LISTENING"') do (
    taskkill /F /PID %%P >nul 2>&1
)
:: Verify port 8080 is now free
timeout /t 1 /nobreak >nul
netstat -aon 2>nul | findstr /i ":8080 " | findstr /i "LISTENING" >nul 2>&1
if errorlevel 1 (
    echo  [OK]   Hub stopped.
) else (
    echo  [WARN] Port 8080 still in use — Hub may not have stopped cleanly.
    set /a STOP_ERRORS+=1
)

:: ── Open WebUI container ──────────────────────────────────────
echo  Stopping Open WebUI container...
docker stop open-webui >nul 2>&1
if errorlevel 1 (
    echo  [INFO] open-webui container was not running.
) else (
    :: Verify container actually stopped
    for /f "tokens=*" %%S in ('docker ps --filter "name=^open-webui$" --format "{{.Names}}" 2^>nul') do set STILL_RUNNING=%%S
    if defined STILL_RUNNING (
        echo  [WARN] open-webui container still shows as running.
        set /a STOP_ERRORS+=1
    ) else (
        echo  [OK]   open-webui stopped.
    )
)

:: ── Ollama ────────────────────────────────────────────────────
echo  Stopping Ollama...
tasklist /FI "IMAGENAME eq ollama.exe" 2>nul | find /i "ollama.exe" >nul
if errorlevel 1 (
    echo  [INFO] Ollama was not running.
) else (
    taskkill /F /IM ollama.exe /T >nul 2>&1
    timeout /t 1 /nobreak >nul
    tasklist /FI "IMAGENAME eq ollama.exe" 2>nul | find /i "ollama.exe" >nul
    if errorlevel 1 (
        echo  [OK]   Ollama stopped.
    ) else (
        echo  [WARN] ollama.exe still running after kill.
        set /a STOP_ERRORS+=1
    )
)

:: ── Update server (PowerShell, title LocalAI-UpdateServer) ───
echo  Stopping update server...
tasklist /FI "WINDOWTITLE eq LocalAI-UpdateServer" 2>nul | find /i "powershell" >nul
if errorlevel 1 (
    echo  [INFO] Update server was not running.
) else (
    taskkill /F /FI "WINDOWTITLE eq LocalAI-UpdateServer" >nul 2>&1
    :: Also kill any powershell holding port 9999
    for /f "tokens=5" %%P in ('netstat -aon 2^>nul ^| findstr /i ":9999 " ^| findstr /i "LISTENING"') do (
        taskkill /F /PID %%P >nul 2>&1
    )
    timeout /t 1 /nobreak >nul
    netstat -aon 2>nul | findstr /i ":9999 " | findstr /i "LISTENING" >nul 2>&1
    if errorlevel 1 (
        echo  [OK]   Update server stopped.
    ) else (
        echo  [WARN] Port 9999 still in use.
        set /a STOP_ERRORS+=1
    )
)

:: ── OpenClaw ──────────────────────────────────────────────────
echo  Stopping OpenClaw...
tasklist /FI "WINDOWTITLE eq OpenClaw" 2>nul | find /i "openclaw" >nul
if errorlevel 1 (
    :: Also check by process name
    tasklist /FI "IMAGENAME eq openclaw.exe" 2>nul | find /i "openclaw" >nul
    if errorlevel 1 (
        echo  [INFO] OpenClaw was not running.
        goto OpenClawDone
    )
)
taskkill /F /FI "WINDOWTITLE eq OpenClaw" >nul 2>&1
taskkill /F /IM openclaw.exe /T >nul 2>&1
timeout /t 1 /nobreak >nul
tasklist /FI "IMAGENAME eq openclaw.exe" 2>nul | find /i "openclaw" >nul
if errorlevel 1 (
    echo  [OK]   OpenClaw stopped.
) else (
    echo  [WARN] openclaw.exe still running.
    set /a STOP_ERRORS+=1
)
:OpenClawDone

:: ── Summary ───────────────────────────────────────────────────
echo.
if %STOP_ERRORS% EQU 0 (
    echo  [OK]   All services stopped successfully.
    color 0A
) else (
    echo  [WARN] %STOP_ERRORS% service(s) may not have stopped cleanly.
    echo         Check Task Manager if needed.
    color 0E
)

if exist "%LOG_FILE%" (
    echo [%date% %time%] Stop sequence complete (errors: %STOP_ERRORS%) >> "%LOG_FILE%"
)
echo.
timeout /t 2 /nobreak >nul
endlocal
