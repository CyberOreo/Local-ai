@echo off
title Local AI - Simple Launcher
color 0A

echo.
echo  ============================================================
echo    LOCAL AI  -  Simple Launcher
echo  ============================================================
echo.

:: ---- Step 1: Start Ollama ------------------------------------
echo  [1/3] Starting Ollama...
tasklist /FI "IMAGENAME eq ollama.exe" 2>nul | findstr /i "ollama.exe" >nul
if not errorlevel 1 (
    echo  [OK]   Ollama already running.
) else (
    start "" /B ollama serve
    echo  [INFO] Ollama started. Waiting 4 seconds...
    timeout /t 4 /nobreak >nul
    echo  [OK]   Ollama started.
)

:: ---- Step 2: Start Docker + open-webui ----------------------
echo.
echo  [2/3] Starting Docker and Open WebUI...

docker info >nul 2>&1
if errorlevel 1 (
    echo  [INFO] Docker not running. Starting Docker Desktop...
    if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" (
        start "" "%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
    ) else if exist "%LOCALAPPDATA%\Programs\Docker\Docker\Docker Desktop.exe" (
        start "" "%LOCALAPPDATA%\Programs\Docker\Docker\Docker Desktop.exe"
    ) else (
        echo  [ERROR] Docker Desktop not found. Please start it manually.
        pause
        exit /b 1
    )
    echo  [INFO] Waiting for Docker to start (up to 60 seconds)...
    set DWAIT=0
    :WaitDocker
    timeout /t 5 /nobreak >nul
    set /a DWAIT+=5
    docker info >nul 2>&1
    if not errorlevel 1 goto DockerOk
    echo  [INFO] Still waiting... (%DWAIT%s)
    if %DWAIT% LSS 60 goto WaitDocker
    echo  [ERROR] Docker did not start in time.
    echo          Please start Docker Desktop manually and try again.
    pause
    exit /b 1
)

:DockerOk
echo  [OK]   Docker is running.

docker start open-webui >nul 2>&1
echo  [OK]   Open WebUI container started (or already running).

:: ---- Step 3: Open browser ------------------------------------
echo.
echo  [3/3] Opening browser...
echo  [INFO] Waiting 5 seconds for Web UI to load...
timeout /t 5 /nobreak >nul
start http://localhost:3000

echo.
echo  ============================================================
echo    LOCAL AI IS RUNNING!
echo.
echo    Open your browser to: http://localhost:3000
echo    If it shows a loading spinner, wait 15 seconds and refresh.
echo.
echo    This window can be closed - the AI keeps running.
echo  ============================================================
echo.
pause
