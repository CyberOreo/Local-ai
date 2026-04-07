@echo off
setlocal EnableDelayedExpansion
title NeuralBox - Health Check
color 0B

:: ============================================================
:: NeuralBox - HEALTH CHECK
:: Tests all services and shows PASS/FAIL status.
:: ============================================================

set "CONFIG_DIR=%~dp0..\..\config"
set "OLLAMA_PORT=11434"
set "WEBUI_PORT=3000"
set "HUB_PORT=8080"
set "UPDATE_PORT=9999"
set "CLAW_PORT=18789"

:: Load port config from .env if available
if exist "%CONFIG_DIR%\.env" (
    for /f "usebackq tokens=1,* delims==" %%A in ("%CONFIG_DIR%\.env") do (
        set line=%%A
        if not "!line:~0,1!"=="#" (
            set "%%A=%%B"
        )
    )
)

echo.
echo  ============================================================
echo    NeuralBox  -  HEALTH CHECK
echo    %date% %time%
echo  ============================================================
echo.

set PASS=0
set FAIL=0

:: ---- Check: Ollama process running ---------------------------
echo  [1] Ollama process...
tasklist /FI "IMAGENAME eq ollama.exe" 2>nul | find /i "ollama.exe" >nul
if errorlevel 1 (
    echo       STATUS: FAIL  (ollama.exe not running)
    set /a FAIL+=1
) else (
    echo       STATUS: PASS
    set /a PASS+=1
)

:: ---- Check: Ollama API responds ------------------------------
echo  [2] Ollama API (http://localhost:%OLLAMA_PORT%)...
curl -s -o nul -w "%%{http_code}" http://localhost:%OLLAMA_PORT% > "%TEMP%\hc_ollama.txt" 2>nul
set /p HC_OLLAMA=<"%TEMP%\hc_ollama.txt"
if "%HC_OLLAMA%"=="200" (
    echo       STATUS: PASS  (HTTP %HC_OLLAMA%)
    set /a PASS+=1
) else if "%HC_OLLAMA%"=="400" (
    echo       STATUS: PASS  (HTTP %HC_OLLAMA% - Ollama running)
    set /a PASS+=1
) else (
    echo       STATUS: FAIL  (HTTP %HC_OLLAMA% - Ollama not responding)
    set /a FAIL+=1
)

:: ---- Check: Docker daemon ------------------------------------
echo  [3] Docker daemon...
docker info >nul 2>&1
if errorlevel 1 (
    echo       STATUS: FAIL  (Docker daemon not running)
    set /a FAIL+=1
) else (
    echo       STATUS: PASS
    set /a PASS+=1
)

:: ---- Check: open-webui container running ---------------------
echo  [4] Open WebUI container...
for /f "tokens=*" %%S in ('docker ps --filter "name=^open-webui$" --format "{{.Status}}" 2^>nul') do (
    set WEBUI_CONTAINER_STATUS=%%S
)
if defined WEBUI_CONTAINER_STATUS (
    echo       STATUS: PASS  (%WEBUI_CONTAINER_STATUS%)
    set /a PASS+=1
) else (
    echo       STATUS: FAIL  (open-webui container not running)
    set /a FAIL+=1
)

:: ---- Check: Web UI HTTP response ----------------------------
echo  [5] Open WebUI HTTP (http://localhost:%WEBUI_PORT%)...
curl -s -o nul -w "%%{http_code}" http://localhost:%WEBUI_PORT% > "%TEMP%\hc_webui.txt" 2>nul
set /p HC_WEBUI=<"%TEMP%\hc_webui.txt"
if "%HC_WEBUI%"=="200" (
    echo       STATUS: PASS  (HTTP %HC_WEBUI%)
    set /a PASS+=1
) else if "%HC_WEBUI%"=="302" (
    echo       STATUS: PASS  (HTTP %HC_WEBUI% - redirect OK)
    set /a PASS+=1
) else (
    echo       STATUS: FAIL  (HTTP %HC_WEBUI% - Web UI not responding)
    set /a FAIL+=1
)

:: ---- Check: NeuralBox Hub ------------------------------------
echo  [6] NeuralBox Hub (http://localhost:%HUB_PORT%)...
curl -s -o nul -w "%%{http_code}" http://localhost:%HUB_PORT% > "%TEMP%\hc_hub.txt" 2>nul
set /p HC_HUB=<"%TEMP%\hc_hub.txt"
if "%HC_HUB%"=="200" (
    echo       STATUS: PASS  (HTTP %HC_HUB%)
    set /a PASS+=1
) else (
    echo       STATUS: FAIL  (HTTP %HC_HUB% - Hub not responding on port %HUB_PORT%)
    set /a FAIL+=1
)

:: ---- Check: Update Server ------------------------------------
echo  [7] Update Server (http://localhost:%UPDATE_PORT%)...
curl -s -o nul -w "%%{http_code}" http://localhost:%UPDATE_PORT%/api/health > "%TEMP%\hc_upd.txt" 2>nul
set /p HC_UPD=<"%TEMP%\hc_upd.txt"
if "%HC_UPD%"=="200" (
    echo       STATUS: PASS  (HTTP %HC_UPD%)
    set /a PASS+=1
) else (
    echo       STATUS: WARN  (HTTP %HC_UPD% - Update server not running; non-critical)
    :: Not a hard failure — update server is optional
)

:: ---- Check: OpenClaw (optional) ------------------------------
echo  [8] OpenClaw agent (http://localhost:%CLAW_PORT%)...
curl -s --max-time 2 -o nul -w "%%{http_code}" http://localhost:%CLAW_PORT% > "%TEMP%\hc_claw.txt" 2>nul
set /p HC_CLAW=<"%TEMP%\hc_claw.txt"
if "%HC_CLAW%"=="200" (
    echo       STATUS: PASS  (HTTP %HC_CLAW%)
    set /a PASS+=1
) else (
    echo       STATUS: WARN  (not running - optional component)
    :: Not a hard failure
)

:: ---- Check: Ollama models API --------------------------------
echo  [9] Ollama models API...
curl -s http://localhost:%OLLAMA_PORT%/api/tags > "%TEMP%\hc_models.txt" 2>nul
findstr /i "models" "%TEMP%\hc_models.txt" >nul 2>&1
if errorlevel 1 (
    echo       STATUS: FAIL  (Could not reach /api/tags)
    set /a FAIL+=1
) else (
    echo       STATUS: PASS
    set /a PASS+=1
)

:: ---- Port usage summary --------------------------------------
echo.
echo  Active ports:
netstat -aon 2>nul | findstr /i "LISTENING" | findstr ":8080 \|:3000 \|:11434 \|:9999 \|:18789 "

:: ---- Summary -------------------------------------------------
echo.
echo  ============================================================
echo    RESULTS:  %PASS% PASSED  /  %FAIL% FAILED
if %FAIL% EQU 0 (
    echo    OVERALL:  ALL REQUIRED SERVICES OPERATIONAL
) else (
    echo    OVERALL:  SOME CHECKS FAILED - see above
    echo.
    echo    TIPS:
    echo    - If Ollama failed:  run start.bat
    echo    - If Docker failed:  start Docker Desktop from taskbar
    echo    - If WebUI failed:   wait 30s then run healthcheck again
    echo    - If Hub failed:     run start.bat (hub starts with launcher^)
    echo    - Full help:         _engine\docs\TROUBLESHOOTING.md
)
echo  ============================================================
echo.
pause
endlocal
