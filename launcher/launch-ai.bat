@echo off
setlocal EnableDelayedExpansion
title Local AI Launcher
color 0A

:: ============================================================
:: LOCAL AI - ONE-CLICK LAUNCHER
:: Double-click this to start Ollama + Open WebUI and open
:: the chat interface in your browser.
:: ============================================================

set "PROJECT_ROOT=%~dp0.."
set "CONFIG_DIR=%PROJECT_ROOT%\config"
set "LOG_DIR=%PROJECT_ROOT%\logs"
set "LOG_FILE=%LOG_DIR%\launch.log"

:: Ensure logs directory exists
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

echo.
echo  ============================================================
echo    LOCAL AI  -  Starting...
echo  ============================================================
echo.

:: Log start
echo [%date% %time%] Launcher started >> "%LOG_FILE%"

:: ---- Load .env config ----------------------------------------
set "OLLAMA_PORT=11434"
set "WEBUI_PORT=3000"
set "PRIMARY_MODEL=qwen3.5:9b"
set "BACKUP_MODEL=qwen3.5:4b"
set "AUTO_OPEN_BROWSER=true"
set "PROFILE=max-performance"

if exist "%CONFIG_DIR%\.env" (
    for /f "usebackq tokens=1,* delims==" %%A in ("%CONFIG_DIR%\.env") do (
        set line=%%A
        if not "!line:~0,1!"=="#" (
            set "%%A=%%B"
        )
    )
)

:: ---- Load profile env ----------------------------------------
set "PROFILE_FILE=%CONFIG_DIR%\profiles\%PROFILE%.env"
if exist "%PROFILE_FILE%" (
    echo  [INFO] Loading performance profile: %PROFILE%
    for /f "usebackq tokens=1,* delims==" %%A in ("%PROFILE_FILE%") do (
        set line=%%A
        if not "!line:~0,1!"=="#" (
            set "%%A=%%B"
        )
    )
) else (
    echo  [WARN] Profile file not found: %PROFILE_FILE%
    echo  [WARN] Using default settings.
)
echo  [INFO] Profile: %PROFILE%
echo  [INFO] Context: %OLLAMA_NUM_CTX% tokens  GPU layers: %OLLAMA_NUM_GPU%  Threads: %OLLAMA_NUM_THREAD%
echo.

:: ============================================================
:: STEP 1: Start Ollama
:: ============================================================
echo  [1/4] Checking Ollama service...

:: Check if Ollama is already running
curl -s -o nul -w "%%{http_code}" http://localhost:%OLLAMA_PORT% > "%TEMP%\ollama_check.txt" 2>nul
set /p OLLAMA_STATUS=<"%TEMP%\ollama_check.txt"

if "%OLLAMA_STATUS%"=="200" (
    echo  [OK]   Ollama is already running.
    goto OllamaReady
)

:: Check if ollama.exe exists
where ollama >nul 2>&1
if errorlevel 1 (
    echo.
    echo  [ERROR] Ollama is not installed!
    echo          Please run install.bat first.
    echo.
    echo [%date% %time%] ERROR: Ollama not installed >> "%LOG_FILE%"
    pause
    exit /b 1
)

echo  [INFO] Starting Ollama...
echo [%date% %time%] Starting Ollama >> "%LOG_FILE%"
start "" /B ollama serve

:: Wait for Ollama to be ready
set WAIT=0
:WaitOllama
timeout /t 2 /nobreak >nul
set /a WAIT+=2
curl -s -o nul -w "%%{http_code}" http://localhost:%OLLAMA_PORT% > "%TEMP%\ollama_check.txt" 2>nul
set /p OLLAMA_STATUS=<"%TEMP%\ollama_check.txt"
if "%OLLAMA_STATUS%"=="200" goto OllamaReady
if "%OLLAMA_STATUS%"=="400" goto OllamaReady
echo  [INFO] Waiting for Ollama... (%WAIT%s)
if %WAIT% LSS 30 goto WaitOllama
echo  [WARN] Ollama took longer than expected. Continuing anyway...

:OllamaReady
echo  [OK]   Ollama is ready on port %OLLAMA_PORT%.
echo [%date% %time%] Ollama ready >> "%LOG_FILE%"

:: ============================================================
:: STEP 2: Ensure Docker Desktop is running
:: ============================================================
echo.
echo  [2/4] Checking Docker Desktop...

docker info >nul 2>&1
if not errorlevel 1 (
    echo  [OK]   Docker daemon is running.
    goto DockerReady
)

echo  [INFO] Docker daemon not running. Starting Docker Desktop...
echo [%date% %time%] Starting Docker Desktop >> "%LOG_FILE%"

:: Try to start Docker Desktop
set "DOCKER_EXE="
if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" (
    set "DOCKER_EXE=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
)
if exist "%USERPROFILE%\AppData\Local\Programs\Docker\Docker\Docker Desktop.exe" (
    set "DOCKER_EXE=%USERPROFILE%\AppData\Local\Programs\Docker\Docker\Docker Desktop.exe"
)

if defined DOCKER_EXE (
    start "" "%DOCKER_EXE%"
    echo  [INFO] Waiting for Docker daemon to start (up to 60s)...
    set DWAIT=0
    :WaitDocker
    timeout /t 5 /nobreak >nul
    set /a DWAIT+=5
    docker info >nul 2>&1
    if not errorlevel 1 goto DockerReady
    echo  [INFO] Waiting for Docker... (%DWAIT%s)
    if %DWAIT% LSS 60 goto WaitDocker
    echo  [ERROR] Docker daemon did not start in time.
    echo          Please start Docker Desktop manually, wait 30 seconds,
    echo          then double-click start.bat again.
    echo [%date% %time%] ERROR: Docker daemon timeout >> "%LOG_FILE%"
    pause
    exit /b 1

) else (
    echo.
    echo  [ERROR] Docker Desktop not found!
    echo          Please install Docker Desktop, start it, then run start.bat again.
    echo          Download: https://www.docker.com/products/docker-desktop/
    echo.
    pause
    exit /b 1
)

:DockerReady
echo  [OK]   Docker daemon is ready.

:: ============================================================
:: STEP 3: Start Open WebUI container
:: ============================================================
echo.
echo  [3/4] Checking Open WebUI container...

:: Check if container exists
for /f "tokens=*" %%C in ('docker ps -a --filter "name=^open-webui$" --format "{{.Names}}" 2^>nul') do (
    set CONTAINER_EXISTS=%%C
)

if not defined CONTAINER_EXISTS (
    echo  [INFO] Creating open-webui container for the first time...
    echo [%date% %time%] Creating open-webui container >> "%LOG_FILE%"
    docker run -d ^
        -p %WEBUI_PORT%:8080 ^
        --add-host=host.docker.internal:host-gateway ^
        -e OLLAMA_BASE_URL=http://host.docker.internal:%OLLAMA_PORT% ^
        -e WEBUI_AUTH=False ^
        -v open-webui:/app/backend/data ^
        --name open-webui ^
        --restart unless-stopped ^
        ghcr.io/open-webui/open-webui:main >nul 2>&1
    if errorlevel 1 (
        echo  [ERROR] Failed to create the open-webui container.
        echo          Make sure Docker Desktop is running and connected to the internet.
        echo          Try: open Docker Desktop, wait for it to fully load, then run start.bat again.
        echo [%date% %time%] ERROR: Failed to create container >> "%LOG_FILE%"
        pause
        exit /b 1
    )
    echo  [OK]   Container created.
    goto WaitWebUI
)

:: Check if container is running
for /f "tokens=*" %%S in ('docker ps --filter "name=^open-webui$" --format "{{.Names}}" 2^>nul') do (
    set CONTAINER_RUNNING=%%S
)

if defined CONTAINER_RUNNING (
    echo  [OK]   open-webui container is already running.
    goto WaitWebUI
)

:: Start stopped container
echo  [INFO] Starting open-webui container...
docker start open-webui >nul 2>&1
echo  [OK]   Container started.

:WaitWebUI
:: ============================================================
:: STEP 4: Wait for Web UI to respond
:: ============================================================
echo.
echo  [4/4] Waiting for Web UI to be ready...
set UWAIT=0
:WaitUI
timeout /t 3 /nobreak >nul
set /a UWAIT+=3
curl -s -o nul -w "%%{http_code}" http://localhost:%WEBUI_PORT% > "%TEMP%\webui_check.txt" 2>nul
set /p WEBUI_STATUS=<"%TEMP%\webui_check.txt"
if "%WEBUI_STATUS%"=="200" goto WebUIReady
if "%WEBUI_STATUS%"=="302" goto WebUIReady
echo  [INFO] Waiting for Web UI... (%UWAIT%s)
if %UWAIT% LSS 90 goto WaitUI
echo  [WARN] Web UI is taking longer than usual. Opening browser anyway...

:WebUIReady
echo  [OK]   Web UI is ready!
echo [%date% %time%] Web UI ready on port %WEBUI_PORT% >> "%LOG_FILE%"

:: ============================================================
:: Start Update Server (enables update button in Open WebUI)
:: ============================================================
echo.
echo  Starting update server (for in-chat update button)...
tasklist /FI "IMAGENAME eq powershell.exe" /FI "WINDOWTITLE eq LocalAI-UpdateServer" >nul 2>&1
curl -s --max-time 2 http://localhost:9999/api/health >nul 2>&1
if not errorlevel 1 (
    echo  [OK]   Update server already running.
) else (
    start "LocalAI-UpdateServer" /min powershell -ExecutionPolicy Bypass -WindowStyle Hidden ^
        -File "%PROJECT_ROOT%\scripts\update-server.ps1" -ProjectRoot "%PROJECT_ROOT%"
    timeout /t 2 /nobreak >nul
    curl -s --max-time 3 http://localhost:9999/api/health >nul 2>&1
    if not errorlevel 1 (
        echo  [OK]   Update server started on port 9999.
    ) else (
        echo  [WARN] Update server slow to start - will be available shortly.
    )
)
echo [%date% %time%] Update server started >> "%LOG_FILE%"

:: ============================================================
:: STEP 4.5: Start OpenClaw Agent
:: ============================================================
echo.
echo  [4.5/5] Starting Clawbot (OpenClaw)...

curl -s --max-time 2 http://localhost:18789 >nul 2>&1
if not errorlevel 1 (
    echo  [OK]   Clawbot already running at localhost:18789
    goto OpenClawReady
)

where openclaw >nul 2>&1
if not errorlevel 1 (
    start "OpenClaw" /min openclaw gateway start --allow-unconfigured
    echo  [INFO] Waiting for Clawbot to start...
    timeout /t 4 /nobreak >nul
    curl -s --max-time 3 http://localhost:18789 >nul 2>&1
    if not errorlevel 1 (
        echo  [OK]   Clawbot started at localhost:18789
    ) else (
        echo  [WARN] Clawbot is starting slowly - will be available shortly.
    )
) else (
    :: Try npm global path directly
    if exist "%APPDATA%\npm\openclaw.cmd" (
        start "OpenClaw" /min "%APPDATA%\npm\openclaw.cmd" gateway start --allow-unconfigured
        timeout /t 4 /nobreak >nul
        echo  [OK]   Clawbot started.
    ) else (
        echo  [WARN] Clawbot not installed yet. Run install-openclaw.bat to install it.
        echo         Local AI Chat will still work normally.
    )
)

:OpenClawReady
echo [%date% %time%] OpenClaw started >> "%LOG_FILE%"

:: ============================================================
:: STEP 4.6: Start LocalAI Hub (unified portal at port 8080)
:: ============================================================
echo.
echo  [4.6/5] Starting LocalAI Hub...

curl -s --max-time 2 http://localhost:8080 >nul 2>&1
if not errorlevel 1 (
    echo  [OK]   LocalAI Hub already running at localhost:8080
    goto HubReady
)

set "HUB_JS=%PROJECT_ROOT%hub\hub.js"
if exist "%HUB_JS%" (
    where node >nul 2>&1
    if not errorlevel 1 (
        start "LocalAI Hub" /min node "%HUB_JS%"
        timeout /t 2 /nobreak >nul
        echo  [OK]   LocalAI Hub started at localhost:8080
    ) else if exist "%ProgramFiles%\nodejs\node.exe" (
        start "LocalAI Hub" /min "%ProgramFiles%\nodejs\node.exe" "%HUB_JS%"
        timeout /t 2 /nobreak >nul
        echo  [OK]   LocalAI Hub started at localhost:8080
    ) else (
        echo  [WARN] Node.js not found - hub unavailable. Run install-openclaw.bat first.
    )
) else (
    echo  [WARN] Hub not found - skipping. Re-download the project to restore it.
)

:HubReady
echo [%date% %time%] LocalAI Hub started >> "%LOG_FILE%"

:: ============================================================
:: Open browser (hub is the main entry point)
:: ============================================================
if /i "%AUTO_OPEN_BROWSER%"=="true" (
    echo.
    echo  Opening LocalAI Hub in your browser...
    start http://localhost:8080
)

:: ============================================================
:: Done - Keep window open
:: ============================================================
echo.
echo  ============================================================
echo    ALL SYSTEMS RUNNING
echo.
echo    LocalAI Hub:    http://localhost:8080   (start here)
echo    Local AI Chat:  http://localhost:%WEBUI_PORT%
echo    Clawbot Agent:  http://localhost:18789/webchat
echo    Ollama:         http://localhost:%OLLAMA_PORT%
echo    Update API:     http://localhost:9999
echo.
echo    Profile:  %PROFILE%   ^|   Model: %PRIMARY_MODEL%
echo.
echo    IN-CHAT UPDATE: type "update" in Local AI Chat
echo    To STOP everything: run launcher\stop-ai.bat
echo  ============================================================
echo.
echo  Press any key to exit this window (services keep running).
echo.
pause >nul

echo [%date% %time%] Launcher window closed (services still running) >> "%LOG_FILE%"
endlocal
