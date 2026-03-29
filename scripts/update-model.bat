@echo off
title Local AI - Update Models
color 0B

:: ============================================================
:: LOCAL AI - UPDATE MODELS
:: Re-pulls the latest versions of installed models.
:: Run this when a new model version is available.
:: ============================================================

set "CONFIG_DIR=%~dp0..\config"
set "LOG_DIR=%~dp0..\logs"
set "LOG_FILE=%LOG_DIR%\update.log"
set "PRIMARY_MODEL=qwen3.5:9b"
set "BACKUP_MODEL=qwen3.5:4b"

:: Load settings from .env if available
if exist "%CONFIG_DIR%\.env" (
    for /f "usebackq tokens=1,* delims==" %%A in ("%CONFIG_DIR%\.env") do (
        set line=%%A
        if not "!line:~0,1!"=="#" set "%%A=%%B"
    )
)

echo.
echo  ============================================================
echo    LOCAL AI  -  MODEL UPDATER
echo  ============================================================
echo.
echo  This will pull the latest versions of:
echo    - %PRIMARY_MODEL%  (primary)
echo    - %BACKUP_MODEL%   (backup)
echo.
echo  Requires internet connection.
echo  Models are stored locally after download.
echo.
set /p CONFIRM="  Continue? [Y/N]: "
if /i not "%CONFIRM%"=="y" (
    echo  Cancelled.
    timeout /t 2 /nobreak >nul
    exit /b 0
)
echo.

:: Check if Ollama is running
where ollama >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Ollama is not installed. Run install.bat first.
    pause
    exit /b 1
)

:: Start Ollama if not running
curl -s -o nul -w "%%{http_code}" http://localhost:11434 > "%TEMP%\update_check.txt" 2>nul
set /p OLLAMA_STATUS=<"%TEMP%\update_check.txt"
if not "%OLLAMA_STATUS%"=="200" if not "%OLLAMA_STATUS%"=="400" (
    echo  [INFO] Starting Ollama service...
    start "" /B ollama serve
    timeout /t 5 /nobreak >nul
)

echo  [1/2] Updating %PRIMARY_MODEL%...
echo [%date% %time%] Updating %PRIMARY_MODEL% >> "%LOG_FILE%"
ollama pull %PRIMARY_MODEL%
if errorlevel 1 (
    echo  [WARN] Failed to update %PRIMARY_MODEL%. Check internet connection.
) else (
    echo  [OK]   %PRIMARY_MODEL% is up to date.
)

echo.
echo  [2/2] Updating %BACKUP_MODEL%...
echo [%date% %time%] Updating %BACKUP_MODEL% >> "%LOG_FILE%"
ollama pull %BACKUP_MODEL%
if errorlevel 1 (
    echo  [WARN] Failed to update %BACKUP_MODEL%. Check internet connection.
) else (
    echo  [OK]   %BACKUP_MODEL% is up to date.
)

echo.
echo  ============================================================
echo    Update complete. Models are ready.
echo    Launch: launcher\launch-ai.bat
echo  ============================================================
echo.
echo [%date% %time%] Model update completed >> "%LOG_FILE%"
pause
