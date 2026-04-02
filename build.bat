@echo off
title NeuralBox — Build Installer
color 0D
echo.
echo  ==========================================
echo    NeuralBox — Build Windows Installer
echo  ==========================================
echo.

:: Check Node.js
where node >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Node.js not found.
    echo         Download it at https://nodejs.org  (LTS version^)
    echo.
    pause
    exit /b 1
)
for /f "tokens=*" %%v in ('node --version') do set NODE_VER=%%v
echo  [OK]  Node.js %NODE_VER%

cd /d "%~dp0app"

:: Install deps if needed
if not exist node_modules (
    echo.
    echo  Installing dependencies...
    npm install
    if errorlevel 1 ( echo  [ERROR] npm install failed. & pause & exit /b 1 )
)

echo.
echo  Building NeuralBox-Setup.exe...
echo  (This takes 1-3 minutes on first run)
echo.
npm run build

if errorlevel 1 (
    echo.
    echo  [ERROR] Build failed. Check output above.
    pause
    exit /b 1
)

echo.
echo  ==========================================
echo    BUILD COMPLETE
echo  ==========================================
echo.
echo  Your installer is at:
echo    %~dp0dist\NeuralBox Setup 1.0.0.exe
echo.
echo  Share that file on TikTok. That's the product.
echo.
pause
