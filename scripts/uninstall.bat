@echo off
title Local AI - Uninstaller
color 0C

:: ============================================================
:: LOCAL AI - UNINSTALLER
:: Removes Open WebUI container, Docker volume, and optionally
:: removes Ollama models and the desktop shortcut.
::
:: NOTE: Ollama itself must be uninstalled via Windows Settings
::       -> Apps -> Ollama -> Uninstall
:: ============================================================

echo.
echo  ============================================================
echo    LOCAL AI  -  UNINSTALLER
echo  ============================================================
echo.
echo  This will remove:
echo    [x] Open WebUI Docker container
echo    [x] Open WebUI Docker volume (chat history!)
echo    [?] Ollama models (will ask)
echo    [x] Desktop shortcut
echo.
echo  WARNING: Removing the Docker volume deletes all chat history.
echo.
set /p CONFIRM="  Are you sure you want to uninstall? [Y/N]: "
if /i not "%CONFIRM%"=="y" (
    echo  Uninstall cancelled.
    timeout /t 2 /nobreak >nul
    exit /b 0
)
echo.

:: ---- Stop Open WebUI container --------------------------------
echo  [1/5] Stopping Open WebUI container...
docker stop open-webui >nul 2>&1
echo  [OK]   Stopped (or was already stopped).

:: ---- Remove Open WebUI container ------------------------------
echo  [2/5] Removing Open WebUI container...
docker rm open-webui >nul 2>&1
if errorlevel 1 (
    echo  [INFO] Container did not exist or already removed.
) else (
    echo  [OK]   Container removed.
)

:: ---- Remove Docker volume (chat history) ----------------------
echo  [3/5] Removing Open WebUI data volume...
echo  WARNING: This permanently deletes all chat history stored in Open WebUI.
set /p DELVOL="  Delete chat history volume? [Y/N]: "
if /i "%DELVOL%"=="y" (
    docker volume rm open-webui >nul 2>&1
    echo  [OK]   Volume removed.
) else (
    echo  [INFO] Volume kept. Chat history is preserved.
    echo  [INFO] You can remove it later with: docker volume rm open-webui
)

:: ---- Remove Ollama models ------------------------------------
echo  [4/5] Ollama models...
where ollama >nul 2>&1
if not errorlevel 1 (
    set /p DELMODELS="  Remove Ollama models (frees ~7 GB)? [Y/N]: "
    if /i "!DELMODELS!"=="y" (
        echo  Removing qwen2.5:8b...
        ollama rm qwen2.5:8b >nul 2>&1
        echo  Removing qwen2.5:8b-maxperf...
        ollama rm qwen2.5:8b-maxperf >nul 2>&1
        echo  Removing qwen2.5:8b-balanced...
        ollama rm qwen2.5:8b-balanced >nul 2>&1
        echo  Removing qwen2.5:8b-safe...
        ollama rm qwen2.5:8b-safe >nul 2>&1
        echo  Removing qwen2.5:3b...
        ollama rm qwen2.5:3b >nul 2>&1
        echo  Removing qwen2.5:3b-fast...
        ollama rm qwen2.5:3b-fast >nul 2>&1
        echo  [OK]   Ollama models removed.
    ) else (
        echo  [INFO] Models kept.
    )
) else (
    echo  [INFO] Ollama not found, skipping model removal.
)

:: ---- Remove desktop shortcut ---------------------------------
echo  [5/5] Removing desktop shortcut...
set "SHORTCUT=%USERPROFILE%\Desktop\Local AI.lnk"
if exist "%SHORTCUT%" (
    del /f /q "%SHORTCUT%"
    echo  [OK]   Desktop shortcut removed.
) else (
    echo  [INFO] No shortcut found on desktop.
)

echo.
echo  ============================================================
echo    Uninstall complete.
echo.
echo    NOTE: Ollama application itself is NOT removed.
echo    To fully uninstall Ollama:
echo      Windows Settings -> Apps -> Ollama -> Uninstall
echo.
echo    To uninstall Docker Desktop:
echo      Windows Settings -> Apps -> Docker Desktop -> Uninstall
echo  ============================================================
echo.
pause
