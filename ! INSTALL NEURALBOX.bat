@echo off
setlocal EnableDelayedExpansion
title NeuralBox Setup
color 0D
chcp 65001 >nul 2>&1

:: ============================================================
:: Self-elevate to admin if needed
:: ============================================================
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo  Requesting administrator access - click YES on the popup...
    powershell -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c \"cd /d \"%~dp0\" && \"! INSTALL NEURALBOX.bat\"\"' -Verb RunAs -Wait"
    exit /b
)

cls
echo.
echo  ============================================================
echo.
echo    NNN   NNN                              lll  BBBBB
echo    NNNN  NNN  eee  uu  uu rrr   aaa      lll  BB  BB   ooo  xx  xx
echo    NN NN NNN e   e uu  uu rr   a   a     lll  BBBBB   o   o  xxxx
echo    NN  NNNN eeeeee uu  uu rr   aaaaa     lll  BB  BB  o   o  xxxx
echo    NN   NNN  eeeee  uuuu  rr    aaaa     lll  BBBBB    ooo  xx  xx
echo.
echo    Your Private AI Empire  --  Version 1.0
echo.
echo  ============================================================
echo.
echo  This installer will set up everything automatically:
echo    [1] Node.js  (hub server)
echo    [2] Ollama   (AI engine)
echo    [3] AI Model (~5 GB download, one time only)
echo    [4] Open WebUI in Docker
echo    [5] NeuralBox Hub at localhost:8080
echo.
echo  Requirements:
echo    Windows 10/11  -  12GB RAM  -  25GB free disk  -  Docker Desktop
echo.
echo  ============================================================
echo.
set /p GO="  Press ENTER to start, or close this window to cancel: "
echo.

set "ROOT=%~dp0"
set "LOG_DIR=%ROOT%logs"
set "LOG=%LOG_DIR%\install.log"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
echo [%date% %time%] Install started > "%LOG%"

:: ============================================================
:: STEP 1: Node.js
:: ============================================================
echo  [1/5] Checking Node.js...
set "NODE_EXE="
where node >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=*" %%V in ('node --version 2^>nul') do set NV=%%V
    echo  [OK]   Node.js !NV! found.
    set "NODE_EXE=node"
    goto NodeDone
)
if exist "%ProgramFiles%\nodejs\node.exe" (
    set "NODE_EXE=%ProgramFiles%\nodejs\node.exe"
    echo  [OK]   Node.js found at Program Files.
    goto NodeDone
)
if exist "%LOCALAPPDATA%\Programs\nodejs\node.exe" (
    set "NODE_EXE=%LOCALAPPDATA%\Programs\nodejs\node.exe"
    echo  [OK]   Node.js found.
    goto NodeDone
)

echo  [INFO] Node.js not found. Downloading v20 LTS (~30 MB)...
echo [%date% %time%] Downloading Node.js >> "%LOG%"
powershell -NoProfile -NonInteractive -Command ^
    "Invoke-WebRequest -Uri 'https://nodejs.org/dist/v20.19.0/node-v20.19.0-x64.msi' -OutFile '$env:TEMP\NodeSetup.msi' -UseBasicParsing"
if not exist "%TEMP%\NodeSetup.msi" (
    echo  [ERROR] Could not download Node.js. Check internet and try again.
    echo [%date% %time%] ERROR: Node.js download failed >> "%LOG%"
    goto Fail
)
echo  [INFO] Installing Node.js silently...
start /wait msiexec /i "%TEMP%\NodeSetup.msi" /quiet /norestart
del "%TEMP%\NodeSetup.msi" >nul 2>&1

:: Refresh PATH
for /f "tokens=*" %%P in ('powershell -NoProfile -Command ^
    "[Environment]::GetEnvironmentVariable(\"Path\",\"Machine\")+\";\"+ [Environment]::GetEnvironmentVariable(\"Path\",\"User\")"') do set "PATH=%%P"

where node >nul 2>&1
if not errorlevel 1 (
    set "NODE_EXE=node"
    echo  [OK]   Node.js installed successfully.
    echo [%date% %time%] Node.js installed OK >> "%LOG%"
) else if exist "%ProgramFiles%\nodejs\node.exe" (
    set "NODE_EXE=%ProgramFiles%\nodejs\node.exe"
    echo  [OK]   Node.js installed.
) else (
    echo  [WARN] Node.js installed but may need a restart. Hub will try to start anyway.
    set "NODE_EXE=%ProgramFiles%\nodejs\node.exe"
)

:NodeDone

:: ============================================================
:: STEP 2: Ollama
:: ============================================================
echo.
echo  [2/5] Checking Ollama...
where ollama >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=*" %%V in ('ollama --version 2^>nul') do set OV=%%V
    echo  [OK]   Ollama !OV! found.
    goto OllamaDone
)
echo  [INFO] Ollama not found. Downloading installer...
echo [%date% %time%] Downloading Ollama >> "%LOG%"
powershell -NoProfile -NonInteractive -Command ^
    "Invoke-WebRequest -Uri 'https://ollama.com/download/OllamaSetup.exe' -OutFile '$env:TEMP\OllamaSetup.exe' -UseBasicParsing"
if not exist "%TEMP%\OllamaSetup.exe" (
    echo  [ERROR] Could not download Ollama. Check internet connection.
    goto Fail
)
echo  [INFO] Installing Ollama...
start /wait "%TEMP%\OllamaSetup.exe" /S
del "%TEMP%\OllamaSetup.exe" >nul 2>&1

for /f "tokens=*" %%P in ('powershell -NoProfile -Command ^
    "[Environment]::GetEnvironmentVariable(\"Path\",\"Machine\")+\";\"+ [Environment]::GetEnvironmentVariable(\"Path\",\"User\")"') do set "PATH=%%P"

where ollama >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Ollama still not found after install. Please install manually: ollama.com/download
    goto Fail
)
echo  [OK]   Ollama installed.
echo [%date% %time%] Ollama installed OK >> "%LOG%"

:OllamaDone

:: ============================================================
:: STEP 3: Start Ollama + Pull Model
:: ============================================================
echo.
echo  [3/5] Starting Ollama service...
curl -s --max-time 3 http://localhost:11434 >nul 2>&1
if errorlevel 1 (
    start "" /B ollama serve
    echo  [INFO] Waiting for Ollama to start...
    set OW=0
    :WaitOllama
        timeout /t 2 /nobreak >nul
        set /a OW+=2
        curl -s --max-time 2 http://localhost:11434 >nul 2>&1
        if not errorlevel 1 goto OllamaUp
        if !OW! LSS 30 goto WaitOllama
    echo  [WARN] Ollama slow to start. Continuing anyway...
)
:OllamaUp
echo  [OK]   Ollama is running.

echo.
echo  [INFO] Downloading AI model qwen3.5:9b (~5 GB - this takes 10-20 min on first run)
echo  [INFO] Go make a coffee - this only happens ONCE.
echo.
ollama pull qwen3.5:9b
if errorlevel 1 (
    echo  [WARN] Model download failed. Check internet and run again. Continuing...
    echo [%date% %time%] WARN: model pull failed >> "%LOG%"
) else (
    echo  [OK]   Model ready.
    echo [%date% %time%] Model pulled OK >> "%LOG%"
)

:: Pull backup model (non-critical)
ollama pull qwen3.5:4b >nul 2>&1

:: ============================================================
:: STEP 4: Docker check
:: ============================================================
echo.
echo  [4/5] Checking Docker Desktop...
docker info >nul 2>&1
if errorlevel 1 (
    echo.
    echo  ============================================================
    echo  [!] Docker Desktop is NOT running.
    echo.
    echo      Please:
    echo        1. Open Docker Desktop from Start Menu
    echo        2. Wait for the whale icon to appear in the taskbar tray
    echo        3. Press ENTER here to continue
    echo  ============================================================
    echo.
    pause
    docker info >nul 2>&1
    if errorlevel 1 (
        echo  [ERROR] Docker still not running. Start Docker Desktop and run this again.
        goto Fail
    )
)
echo  [OK]   Docker is running.

:: Create open-webui container if not exists
echo  [INFO] Setting up Open WebUI container...
set "WEBUI_IMAGE=ghcr.io/open-webui/open-webui:v0.6.5"
set "WEBUI_PORT=3000"

for /f "tokens=*" %%C in ('docker ps -a --filter "name=^open-webui$" --format "{{.Names}}" 2^>nul') do set "EXISTS=%%C"

if not defined EXISTS (
    echo  [INFO] Creating open-webui container (downloading ~1.5 GB)...
    docker run -d ^
        -p 127.0.0.1:%WEBUI_PORT%:8080 ^
        --add-host=host.docker.internal:host-gateway ^
        -e OLLAMA_BASE_URL=http://host.docker.internal:11434 ^
        -e WEBUI_AUTH=False ^
        -v open-webui:/app/backend/data ^
        --name open-webui ^
        --restart unless-stopped ^
        %WEBUI_IMAGE%
    if errorlevel 1 (
        echo  [ERROR] Could not create container. Is Docker Desktop running and connected to internet?
        goto Fail
    )
    echo  [OK]   Container created.
) else (
    docker start open-webui >nul 2>&1
    echo  [OK]   Container started.
)

:: ============================================================
:: STEP 5: Start NeuralBox Hub
:: ============================================================
echo.
echo  [5/5] Starting NeuralBox Hub...
set "HUB_JS=%ROOT%hub\hub.js"
if exist "%HUB_JS%" (
    if defined NODE_EXE (
        start "NeuralBox Hub" /min "!NODE_EXE!" "%HUB_JS%"
        timeout /t 3 /nobreak >nul
        echo  [OK]   Hub starting at localhost:8080
    )
) else (
    echo  [WARN] hub.js not found. Make sure all files are extracted.
)

:: Write installed flag
echo %date% %time% > "%ROOT%config\.installed"
echo [%date% %time%] Installation complete >> "%LOG%"

:: ============================================================
:: DONE
:: ============================================================
echo.
echo  ============================================================
echo    DONE! NeuralBox is ready.
echo.
echo    Opening in your browser now...
echo.
echo    NeuralBox Hub:  http://localhost:8080   ^<-- use this
echo    Open WebUI:     http://localhost:3000
echo.
echo    Next time: just double-click start.bat
echo  ============================================================
echo.

timeout /t 3 /nobreak >nul
start http://localhost:8080
timeout /t 2 /nobreak >nul
start http://localhost:3000

echo  Press any key to close this window (everything keeps running).
pause >nul
exit /b 0

:Fail
echo.
echo  ============================================================
echo  [ERROR] Setup could not complete. See above for the reason.
echo  Log file: %LOG%
echo  ============================================================
echo.
pause
exit /b 1
