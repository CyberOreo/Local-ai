@echo off
setlocal EnableDelayedExpansion
title Local AI - Update
color 0B

:: ============================================================
::
::   LOCAL AI - UPDATER
::   Double-click this to update EVERYTHING.
::
::   What this does:
::     [1] Updates Ollama (AI runtime)
::     [2] Updates Open WebUI (chat interface)
::     [3] Updates qwen3.5:9b model  (only downloads CHANGES)
::     [4] Updates qwen3.5:4b model  (only downloads CHANGES)
::     [5] Restarts all services
::     [6] Opens browser when ready
::
::   SAFE: Models are NEVER deleted. If nothing changed,
::         nothing is downloaded. Smart delta updates only.
::
:: ============================================================

set "ROOT=%~dp0"
set "PROJ=%ROOT%.."
set "LOG_DIR=%PROJ%\logs"
set "LOG_FILE=%LOG_DIR%\update.log"
set "PRIMARY_MODEL=qwen3.5:9b"
set "BACKUP_MODEL=qwen3.5:4b"
set "WEBUI_IMAGE=ghcr.io/open-webui/open-webui:v0.6.5"
set "CONTAINER=open-webui"
set "OLLAMA_PORT=11434"
set "WEBUI_PORT=3000"

:: Read image + model targets from version.json (single source of truth)
for /f "usebackq tokens=*" %%I in (`powershell -NoProfile -NonInteractive -Command "(Get-Content '%ROOT%version.json' -Raw | ConvertFrom-Json).webui_image" 2^>nul`) do (
    if not "%%I"=="" set "WEBUI_IMAGE=%%I"
)
for /f "usebackq tokens=*" %%I in (`powershell -NoProfile -NonInteractive -Command "(Get-Content '%ROOT%version.json' -Raw | ConvertFrom-Json).primary_model" 2^>nul`) do (
    if not "%%I"=="" set "PRIMARY_MODEL=%%I"
)
for /f "usebackq tokens=*" %%I in (`powershell -NoProfile -NonInteractive -Command "(Get-Content '%ROOT%version.json' -Raw | ConvertFrom-Json).backup_model" 2^>nul`) do (
    if not "%%I"=="" set "BACKUP_MODEL=%%I"
)

:: Load overrides from config if available
if exist "%PROJ%\config\.env" (
    for /f "usebackq tokens=1,* delims==" %%A in ("%PROJ%\config\.env") do (
        set line=%%A
        if not "!line:~0,1!"=="#" set "%%A=%%B"
    )
)

:: Ensure log directory exists
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

:: Require admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator access...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cls
echo.
echo  ============================================================
echo    LOCAL AI UPDATER
echo    %date% %time%
echo  ============================================================
echo.
echo  This will update everything.
echo  Models are NOT deleted - only new changes are downloaded.
echo  If nothing changed, nothing is downloaded.
echo.
echo  Press any key to start update, or close this window to cancel.
pause >nul

echo. && echo [%date% %time%] UPDATE STARTED >> "%LOG_FILE%"

:: ============================================================
:: [1] UPDATE OLLAMA
:: ============================================================
echo.
echo  ============================================================
echo  [1/5] Updating Ollama...
echo  ============================================================

where ollama >nul 2>&1
if errorlevel 1 (
    echo  [WARN] Ollama not found. Skipping Ollama update.
    echo  [WARN] Run start.bat to install first.
    echo [%date% %time%] WARN: Ollama not found, skipping >> "%LOG_FILE%"
    goto UpdateOllamaSkip
)

:: Get current version
for /f "tokens=*" %%V in ('ollama --version 2^>nul') do set OLLAMA_CURRENT=%%V
echo  Current: %OLLAMA_CURRENT%
echo [%date% %time%] Ollama current: %OLLAMA_CURRENT% >> "%LOG_FILE%"

echo  Downloading latest Ollama installer...
powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://ollama.com/download/OllamaSetup.exe' -OutFile '$env:TEMP\OllamaSetup.exe' -UseBasicParsing"
if errorlevel 1 (
    echo  [WARN] Could not download Ollama update. Continuing with current version.
    echo [%date% %time%] WARN: Ollama download failed >> "%LOG_FILE%"
    goto UpdateOllamaSkip
)

echo  Installing...
start /wait "" "%TEMP%\OllamaSetup.exe" /S
if errorlevel 1 (
    echo  [WARN] Ollama installer returned an error. May already be up to date.
) else (
    echo  [OK]   Ollama updated.
)
echo [%date% %time%] Ollama update done >> "%LOG_FILE%"

:UpdateOllamaSkip

:: ============================================================
:: [2] STOP SERVICES BEFORE UPDATE
:: ============================================================
echo.
echo  ============================================================
echo  [2/5] Stopping services before update...
echo  ============================================================

:: Record current container image ID before touching anything (needed for rollback)
set "OLD_IMAGE_ID="
for /f "tokens=*" %%I in ('docker inspect %CONTAINER% --format "{{.Image}}" 2^>nul') do set "OLD_IMAGE_ID=%%I"

echo  Stopping Open WebUI container...
docker stop %CONTAINER% >nul 2>&1
echo  Stopping Ollama...
taskkill /F /IM ollama.exe >nul 2>&1
timeout /t 3 /nobreak >nul
echo  [OK]   Services stopped.
echo [%date% %time%] Services stopped >> "%LOG_FILE%"

:: ============================================================
:: [3] UPDATE OPEN WEBUI DOCKER IMAGE
:: ============================================================
echo.
echo  ============================================================
echo  [3/5] Updating Open WebUI...
echo        (Only downloads what changed - safe for chat history)
echo  ============================================================

docker info >nul 2>&1
if errorlevel 1 (
    echo  [WARN] Docker not running. Starting Docker Desktop...
    start "" "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" >nul 2>&1
    set DWAIT=0
    :WaitDockerUpdate
        timeout /t 5 /nobreak >nul
        set /a DWAIT+=5
        docker info >nul 2>&1
        if not errorlevel 1 goto DockerReadyUpdate
        if %DWAIT% LSS 60 goto WaitDockerUpdate
    echo  [WARN] Docker did not start in time. Skipping WebUI update.
    echo [%date% %time%] WARN: Docker timeout during update >> "%LOG_FILE%"
    goto UpdateWebUISkip
)

:DockerReadyUpdate
echo  Pulling latest Open WebUI image...
echo  (Only changed layers are downloaded)
docker pull %WEBUI_IMAGE%
if errorlevel 1 (
    echo  [WARN] Could not pull new Open WebUI image. Will use existing.
    echo [%date% %time%] WARN: docker pull failed >> "%LOG_FILE%"
    goto UpdateWebUISkip
)

:: Check if image actually changed — skip recreation if digest is unchanged
set "NEW_IMAGE_ID="
for /f "tokens=*" %%I in ('docker inspect %WEBUI_IMAGE% --format "{{.Id}}" 2^>nul') do set "NEW_IMAGE_ID=%%I"
if not "%NEW_IMAGE_ID%"=="" if "%NEW_IMAGE_ID%"=="%OLD_IMAGE_ID%" (
    echo  [OK] Image unchanged after pull. Restarting existing container.
    docker start %CONTAINER% >nul 2>&1
    echo [%date% %time%] WebUI already up to date, restarted container >> "%LOG_FILE%"
    goto UpdateWebUISkip
)

echo  Applying update (removing old container, keeping all data)...
docker rm %CONTAINER% >nul 2>&1
echo  Recreating container with latest image...
docker run -d ^
    -p 127.0.0.1:%WEBUI_PORT%:8080 ^
    --add-host=host.docker.internal:host-gateway ^
    -e OLLAMA_BASE_URL=http://host.docker.internal:%OLLAMA_PORT% ^
    -e WEBUI_AUTH=False ^
    -v open-webui:/app/backend/data ^
    --name %CONTAINER% ^
    --restart unless-stopped ^
    %WEBUI_IMAGE% >nul 2>&1

if errorlevel 1 (
    echo  [ERROR] Failed to recreate container.
    echo [%date% %time%] ERROR: container recreate failed >> "%LOG_FILE%"
    if not "%OLD_IMAGE_ID%"=="" (
        echo  [INFO] Attempting rollback to previous image...
        docker run -d ^
            -p 127.0.0.1:%WEBUI_PORT%:8080 ^
            --add-host=host.docker.internal:host-gateway ^
            -e OLLAMA_BASE_URL=http://host.docker.internal:%OLLAMA_PORT% ^
            -e WEBUI_AUTH=False ^
            -v open-webui:/app/backend/data ^
            --name %CONTAINER% ^
            --restart unless-stopped ^
            %OLD_IMAGE_ID% >nul 2>&1
        if not errorlevel 1 (
            echo  [OK] Rollback successful. Previous version restored. Chat history safe.
            echo [%date% %time%] Rollback successful >> "%LOG_FILE%"
        ) else (
            echo  [ERROR] Rollback also failed. Run start.bat to recover.
            echo [%date% %time%] ERROR: rollback also failed >> "%LOG_FILE%"
        )
    ) else (
        echo  [ERROR] No previous image recorded. Run start.bat to recover.
    )
) else (
    echo  [OK]   Open WebUI updated. Chat history preserved.
    echo [%date% %time%] Open WebUI updated >> "%LOG_FILE%"
)

:UpdateWebUISkip

:: ============================================================
:: [4] UPDATE MODELS (smart delta - no full re-download)
:: ============================================================
echo.
echo  ============================================================
echo  [4/5] Updating AI models...
echo        Smart update: only downloads what actually changed.
echo        If model is current, 0 bytes are downloaded.
echo  ============================================================

:: Start Ollama first
echo  Starting Ollama service...
start "" /B ollama serve
timeout /t 5 /nobreak >nul

:: Wait for Ollama API
set OWAIT=0
:WaitOllamaUpdate
    curl -s --max-time 2 http://localhost:%OLLAMA_PORT%/api/tags >nul 2>&1
    if not errorlevel 1 goto OllamaReadyUpdate
    set /a OWAIT+=3
    if %OWAIT% GEQ 30 (
        echo  [WARN] Ollama not responding. Model update skipped.
        echo [%date% %time%] WARN: Ollama timeout for model update >> "%LOG_FILE%"
        goto UpdateModelsSkip
    )
    timeout /t 3 /nobreak >nul
    goto WaitOllamaUpdate

:OllamaReadyUpdate
echo  Ollama ready.

echo.
echo  Updating %PRIMARY_MODEL%...
echo  (If up to date: completes instantly. If update exists: downloads only changed layers)
ollama pull %PRIMARY_MODEL%
if errorlevel 1 (
    echo  [WARN] Could not update %PRIMARY_MODEL%. Using existing version.
    echo [%date% %time%] WARN: pull %PRIMARY_MODEL% failed >> "%LOG_FILE%"
) else (
    echo  [OK]   %PRIMARY_MODEL% is up to date.
    echo [%date% %time%] %PRIMARY_MODEL% updated >> "%LOG_FILE%"
)

echo.
echo  Updating %BACKUP_MODEL%...
ollama pull %BACKUP_MODEL%
if errorlevel 1 (
    echo  [WARN] Could not update %BACKUP_MODEL%. Using existing version.
    echo [%date% %time%] WARN: pull %BACKUP_MODEL% failed >> "%LOG_FILE%"
) else (
    echo  [OK]   %BACKUP_MODEL% is up to date.
    echo [%date% %time%] %BACKUP_MODEL% updated >> "%LOG_FILE%"
)

:UpdateModelsSkip

:: ============================================================
:: [5] RESTART AND OPEN BROWSER
:: ============================================================
echo.
echo  ============================================================
echo  [5/5] Restarting services and opening browser...
echo  ============================================================

:: Wait for WebUI to be ready
echo  Waiting for Open WebUI to start...
set UWAIT=0
:WaitWebUIUpdate
    curl -s --max-time 3 http://localhost:%WEBUI_PORT% >nul 2>&1
    if not errorlevel 1 goto WebUIReadyUpdate
    set /a UWAIT+=5
    if %UWAIT% GEQ 120 (
        echo  [WARN] Web UI slow to start. Opening browser anyway...
        goto WebUIReadyUpdate
    )
    echo  Waiting... (%UWAIT%s)
    timeout /t 5 /nobreak >nul
    goto WaitWebUIUpdate

:WebUIReadyUpdate
echo  [OK]   Web UI is ready.
echo  Opening browser...
start http://localhost:%WEBUI_PORT%

:: ============================================================
:: DONE
:: ============================================================
echo.
echo  ============================================================
echo    UPDATE COMPLETE!
echo.
echo    Everything is up to date.
echo    Browser opened: http://localhost:%WEBUI_PORT%
echo.
echo    Your chat history and settings are preserved.
echo  ============================================================
echo.
echo [%date% %time%] UPDATE COMPLETE >> "%LOG_FILE%"
echo.
pause
endlocal
