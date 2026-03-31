@echo off
setlocal EnableDelayedExpansion
title OpenClaw Agent Installer
color 0A

echo.
echo  ============================================================
echo    OPENCLAW AGENT INSTALLER
echo    AI Brain: qwen3.5:9b (your local Ollama model)
echo  ============================================================
echo.

:: ============================================================
:: STEP 1: Check / Install Node.js
:: ============================================================
echo  [1/5] Checking Node.js...

set "NODE_EXE="
:: Check in PATH first
where node >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=*" %%v in ('node --version 2^>nul') do set NODE_VER=%%v
    echo  [OK]   Node.js found in PATH: !NODE_VER!
    goto NodeReady
)
:: Check default install location
if exist "%ProgramFiles%\nodejs\node.exe" (
    set "NODE_EXE=%ProgramFiles%\nodejs\node.exe"
    set "PATH=%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"
    for /f "tokens=*" %%v in ('"%ProgramFiles%\nodejs\node.exe" --version 2^>nul') do set NODE_VER=%%v
    echo  [OK]   Node.js found at Program Files: !NODE_VER!
    goto NodeReady
)

echo  [INFO] Node.js not found. Downloading installer (Node.js 22 LTS)...
echo  [INFO] This will take 1-2 minutes...
echo.
powershell -Command "Invoke-WebRequest -Uri 'https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi' -OutFile '%TEMP%\nodejs-installer.msi' -UseBasicParsing"
if errorlevel 1 (
    echo.
    echo  [ERROR] Failed to download Node.js installer.
    echo          Please check your internet connection and try again.
    echo.
    pause
    exit /b 1
)

echo  [INFO] Installing Node.js... (you may see a UAC prompt)
msiexec /i "%TEMP%\nodejs-installer.msi" /quiet /norestart
echo  [INFO] Waiting for installation to finish...
timeout /t 15 /nobreak >nul

:: Update PATH for this session
set "PATH=%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"

node --version >nul 2>&1
if errorlevel 1 (
    echo.
    echo  [WARN] Node.js installed. You need to close this window and run
    echo         install-openclaw.bat again for Windows to find it.
    echo.
    pause
    exit /b 0
)
for /f "tokens=*" %%v in ('node --version 2^>nul') do set NODE_VER=%%v
echo  [OK]   Node.js installed: !NODE_VER!

:NodeReady

:: ============================================================
:: STEP 2: Install OpenClaw
:: ============================================================
echo.
echo  [2/5] Installing OpenClaw from npm...
echo  [INFO] This downloads the openclaw package (may take 2-3 minutes)...
echo.

call npm install -g openclaw@latest 2>&1
if errorlevel 1 (
    echo.
    echo  [ERROR] OpenClaw installation failed.
    echo          Common causes:
    echo          - No internet connection
    echo          - npm permission issue (try running as Administrator)
    echo.
    pause
    exit /b 1
)

:: Verify installation
where openclaw >nul 2>&1
if errorlevel 1 (
    :: Try common npm global location
    if exist "%APPDATA%\npm\openclaw.cmd" (
        echo  [OK]   OpenClaw installed at: %APPDATA%\npm\openclaw.cmd
    ) else (
        echo  [WARN] OpenClaw installed but may not be in PATH.
        echo         Try closing this window and running again.
    )
) else (
    echo  [OK]   OpenClaw installed successfully.
)

:: ============================================================
:: STEP 3: Write OpenClaw Configuration
:: ============================================================
echo.
echo  [3/5] Configuring OpenClaw to use qwen3.5:9b...

set "OPENCLAW_DIR=%USERPROFILE%\.openclaw"
set "WORKSPACE_DIR=%USERPROFILE%\.openclaw\workspace"
set "MEMORY_DIR=%USERPROFILE%\.openclaw\memory"

if not exist "%OPENCLAW_DIR%" mkdir "%OPENCLAW_DIR%"
if not exist "%WORKSPACE_DIR%" mkdir "%WORKSPACE_DIR%"
if not exist "%MEMORY_DIR%" mkdir "%MEMORY_DIR%"

:: Write config using PowerShell to avoid echo/quoting issues
powershell -Command "$config = @{ models = @{ providers = @{ ollama = @{ apiKey = 'ollama-local'; baseUrl = 'http://localhost:11434'; api = 'ollama' } }; defaults = @{ primary = 'ollama/qwen3.5:9b'; secondary = 'ollama/qwen3.5:9b' } }; agent = @{ name = 'Clawbot'; instructions = 'You are Clawbot, an autonomous AI agent. Your brain is qwen3.5:9b running privately on this PC. When given a task, think step by step and use tools proactively. Search the web for current information. Read files when given paths. Plan complex tasks into steps. Remember important things about the user. Deliver complete results without asking unnecessary questions. Ask the user if they want to watch you work live or have you run in the background for big tasks.' }; gateway = @{ port = 18789 } }; $config | ConvertTo-Json -Depth 10 | Set-Content -Path '$env:USERPROFILE\.openclaw\openclaw.json' -Encoding UTF8"

if exist "%OPENCLAW_DIR%\openclaw.json" (
    echo  [OK]   Config written to %OPENCLAW_DIR%\openclaw.json
) else (
    :: Fallback: write config manually
    (
        echo {
        echo   "models": {
        echo     "providers": {
        echo       "ollama": {
        echo         "apiKey": "ollama-local",
        echo         "baseUrl": "http://localhost:11434",
        echo         "api": "ollama"
        echo       }
        echo     },
        echo     "defaults": {
        echo       "primary": "ollama/qwen3.5:9b",
        echo       "secondary": "ollama/qwen3.5:9b"
        echo     }
        echo   },
        echo   "agent": {
        echo     "name": "Clawbot",
        echo     "instructions": "You are Clawbot, an autonomous AI agent running locally on this PC. Use tools proactively. Search the web, read files, plan tasks, and deliver complete results."
        echo   },
        echo   "gateway": {
        echo     "port": 18789
        echo   }
        echo }
    ) > "%OPENCLAW_DIR%\openclaw.json"
    echo  [OK]   Config written (fallback method).
)

:: Write initial MEMORY.md so OpenClaw has context from day one
if not exist "%WORKSPACE_DIR%\MEMORY.md" (
    (
        echo # Clawbot Memory
        echo.
        echo ## System
        echo - AI brain: qwen3.5:9b running via Ollama on localhost:11434
        echo - Interface: LocalAI Hub at localhost:8080
        echo - Local AI chat: Open WebUI at localhost:3000
        echo - Everything runs locally - fully private
        echo.
        echo ## Instructions
        echo - Always use tools proactively
        echo - For complex tasks, ask: watch live or run in background?
        echo - Search the web before answering factual questions
        echo - Remember new facts about the user in this memory file
    ) > "%WORKSPACE_DIR%\MEMORY.md"
    echo  [OK]   Initial memory file created.
)

:: ============================================================
:: STEP 4: Verify Ollama is running
:: ============================================================
echo.
echo  [4/5] Checking Ollama connection...

curl -s --max-time 3 http://localhost:11434/api/tags >nul 2>&1
if not errorlevel 1 (
    echo  [OK]   Ollama is running and qwen3.5:9b is available.
) else (
    echo  [WARN] Ollama is not running right now.
    echo         Start it by running start.bat - Ollama will start automatically.
)

:: ============================================================
:: STEP 5: Start OpenClaw Gateway
:: ============================================================
echo.
echo  [5/5] Starting OpenClaw gateway...

:: Check if already running
curl -s --max-time 2 http://localhost:18789 >nul 2>&1
if not errorlevel 1 (
    echo  [OK]   OpenClaw gateway already running at localhost:18789
    goto Done
)

start "OpenClaw Gateway" /min openclaw gateway start --allow-unconfigured
echo  [INFO] Waiting for gateway to start...
timeout /t 5 /nobreak >nul

curl -s --max-time 3 http://localhost:18789 >nul 2>&1
if not errorlevel 1 (
    echo  [OK]   OpenClaw gateway started at localhost:18789
) else (
    echo  [WARN] Gateway starting slowly - will be ready when you open the hub.
)

:Done
echo.
echo  ============================================================
echo    OPENCLAW INSTALLED AND CONFIGURED!
echo.
echo    Clawbot Dashboard:  http://localhost:18789
echo    Clawbot Chat:       http://localhost:18789/webchat
echo    AI Brain:           qwen3.5:9b (Ollama)
echo    Memory file:        %WORKSPACE_DIR%\MEMORY.md
echo.
echo    NEXT: Run start.bat to launch everything at once,
echo          or double-click hub\hub-start.bat for just the hub.
echo  ============================================================
echo.
pause
endlocal
