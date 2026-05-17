@echo off
title NeuralBox - Diagnostics
color 0E
chcp 65001 >nul 2>&1

cls
echo.
echo  ============================================================
echo    NEURALBOX DIAGNOSTICS
echo    Checking everything...
echo  ============================================================
echo.

set ERRORS=0
set WARNINGS=0

:: ---- [1] Node.js ----------------------------------------
echo  [1/6] Node.js (required for the hub portal)...
where node >nul 2>&1
if errorlevel 1 (
    echo  [MISSING] Node.js is NOT installed!
    echo           Download: https://nodejs.org  (LTS version)
    echo           After install, restart this script.
    set /a ERRORS+=1
) else (
    for /f "tokens=*" %%V in ('node --version 2^>nul') do set NODE_VER=%%V
    echo  [OK]     Node.js %NODE_VER%
)

:: ---- [2] Ollama -----------------------------------------
echo.
echo  [2/6] Ollama (AI engine)...
where ollama >nul 2>&1
if errorlevel 1 (
    echo  [MISSING] Ollama is NOT installed!
    echo           Download: https://ollama.com/download
    set /a ERRORS+=1
) else (
    for /f "tokens=*" %%V in ('ollama --version 2^>nul') do set OLLAMA_VER=%%V
    echo  [OK]     Ollama %OLLAMA_VER%
)

:: ---- [3] Ollama running? --------------------------------
echo.
echo  [3/6] Ollama service (must be running)...
curl -s --max-time 3 http://localhost:11434 >nul 2>&1
if errorlevel 1 (
    echo  [WARN]   Ollama is installed but NOT running.
    echo           Starting it now...
    start "" /B ollama serve
    timeout /t 5 /nobreak >nul
    curl -s --max-time 3 http://localhost:11434 >nul 2>&1
    if errorlevel 1 (
        echo  [ERROR]  Ollama still not responding. Try running 'ollama serve' manually.
        set /a ERRORS+=1
    ) else (
        echo  [OK]     Ollama started successfully.
    )
) else (
    echo  [OK]     Ollama is running at localhost:11434
)

:: ---- [4] Docker -----------------------------------------
echo.
echo  [4/6] Docker Desktop...
where docker >nul 2>&1
if errorlevel 1 (
    echo  [MISSING] Docker is NOT installed!
    echo           Download: https://www.docker.com/products/docker-desktop/
    echo           Install it, start it, then run this script again.
    set /a ERRORS+=1
) else (
    docker info >nul 2>&1
    if errorlevel 1 (
        echo  [WARN]   Docker is installed but NOT running.
        echo           Please open Docker Desktop, wait for the whale icon in tray,
        echo           then run this script again.
        set /a ERRORS+=1
    ) else (
        echo  [OK]     Docker is running.
    )
)

:: ---- [5] Open WebUI container ---------------------------
echo.
echo  [5/6] Open WebUI (chat interface at localhost:3000)...
curl -s --max-time 3 http://localhost:3000 >nul 2>&1
if errorlevel 1 (
    echo  [WARN]   Open WebUI is not responding at localhost:3000
    docker ps --filter "name=open-webui" --format "{{.Names}}" 2>nul | findstr "open-webui" >nul
    if errorlevel 1 (
        echo           Container doesn't exist. Run  ! INSTALL NEURALBOX.bat  to create it.
        set /a WARNINGS+=1
    ) else (
        echo           Container exists but is stopped. Starting it...
        docker start open-webui >nul 2>&1
        echo           Started. May take 30-60 seconds to load.
    )
) else (
    echo  [OK]     Open WebUI is running at localhost:3000
)

:: ---- [6] NeuralBox Hub ----------------------------------
echo.
echo  [6/6] NeuralBox Hub (your AI tools at localhost:8080)...
curl -s --max-time 3 http://localhost:8080 >nul 2>&1
if errorlevel 1 (
    echo  [WARN]   Hub not running at localhost:8080.
    echo           Starting it now...
    set "HUB_JS=%~dp0hub\hub.js"
    if not exist "%HUB_JS%" (
        echo  [ERROR]  hub\hub.js not found! Make sure you extracted ALL files.
        set /a ERRORS+=1
    ) else (
        where node >nul 2>&1
        if not errorlevel 1 (
            start "NeuralBox Hub" /min node "%HUB_JS%"
            timeout /t 3 /nobreak >nul
            curl -s --max-time 3 http://localhost:8080 >nul 2>&1
            if not errorlevel 1 (
                echo  [OK]     Hub started at localhost:8080
            ) else (
                echo  [WARN]   Hub is starting slowly. Try opening localhost:8080 in 10 seconds.
            )
        ) else (
            echo  [ERROR]  Node.js missing - cannot start hub. Install Node.js first.
        )
    )
) else (
    echo  [OK]     NeuralBox Hub is running at localhost:8080
)

:: ---- Summary --------------------------------------------
echo.
echo  ============================================================
if %ERRORS% gtr 0 (
    echo   RESULT: %ERRORS% problem(s) found. Fix the [MISSING]/[ERROR] items above.
    echo.
    echo   Most common fixes:
    echo     1. Install Node.js   -> nodejs.org  (LTS)
    echo     2. Install Ollama    -> ollama.com/download
    echo     3. Install Docker    -> docker.com/products/docker-desktop
    echo     4. START Docker Desktop and wait for whale icon in tray
    echo     5. Then run  ! INSTALL NEURALBOX.bat  again
) else (
    echo   ALL CHECKS PASSED! Opening NeuralBox now...
    echo.
    start http://localhost:8080
    timeout /t 2 /nobreak >nul
    start http://localhost:3000
)
echo  ============================================================
echo.
pause
