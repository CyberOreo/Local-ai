@echo off
title Local AI - Installing Skill Packages
color 0B

:: ============================================================
:: LOCAL AI - SKILL PACKAGE INSTALLER
:: Installs Python packages into the Open WebUI Docker container
:: so the skill tools work.
::
:: Run this ONCE after install, and again after update.bat.
:: ============================================================

echo.
echo  ============================================================
echo    LOCAL AI  -  Installing Skill Packages
echo  ============================================================
echo.

:: Check Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Docker is not running!
    echo          Start Docker Desktop first, then run this again.
    echo.
    pause
    exit /b 1
)

:: Check open-webui container exists and is running
docker ps --filter "name=^open-webui$" --format "{{.Names}}" | findstr /i "open-webui" >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] open-webui container is not running!
    echo          Run start.bat first to start Local AI, then run this again.
    echo.
    pause
    exit /b 1
)

echo  [INFO] Installing packages into open-webui container...
echo         This takes about 1-2 minutes.
echo.

docker exec open-webui pip install --quiet --no-warn-script-location ^
    youtube-transcript-api ^
    requests ^
    beautifulsoup4 ^
    pypdf ^
    python-docx ^
    openpyxl ^
    lxml

if errorlevel 1 (
    echo.
    echo  [WARN] Some packages may have failed to install.
    echo         Check the output above for details.
) else (
    echo.
    echo  [OK]   All skill packages installed successfully!
)

echo.
echo  ============================================================
echo    INSTALLED PACKAGES:
echo      youtube-transcript-api  - YouTube transcript fetcher
echo      beautifulsoup4          - Article extractor + web search
echo      pypdf                   - PDF reader
echo      python-docx             - Word document reader
echo      openpyxl                - Excel spreadsheet reader
echo      lxml                    - HTML parser (faster bs4)
echo.
echo    Tools ready to use in Open WebUI chat!
echo  ============================================================
echo.
echo  NOTE: Re-run this file after running update.bat,
echo        as container updates wipe installed packages.
echo.
pause
