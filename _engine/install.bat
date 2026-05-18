@echo off
title Local AI - Installer
color 0B

:: ============================================================
:: Local AI Installer - Entry Point
:: Run this ONCE to set up everything.
:: Right-click this file and choose "Run as administrator"
:: ============================================================

echo.
echo  ============================================================
echo    LOCAL AI INSTALLER
echo    Powered by Ollama + Open WebUI
echo  ============================================================
echo.

:: --- Check for Administrator privileges ---
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo  [!] This installer requires Administrator privileges.
    echo  [!] Restarting with elevated permissions...
    echo.
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    echo  Waiting for elevated installer window...
    pause
    exit /b
)

echo  [OK] Running as Administrator.
echo.

:: --- Run the PowerShell installer ---
echo  Starting installer...
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0install.ps1" -ProjectRoot "%~dp0.."

if %errorLevel% neq 0 (
    echo.
    echo  ============================================================
    echo  [ERROR] Installation failed. See logs\install.log for details.
    echo  ============================================================
    echo.
    pause
    exit /b 1
)

echo.
echo  ============================================================
echo  [SUCCESS] Installation complete!
echo  To launch: double-click  launcher\launch-ai.bat
echo  Or use the desktop shortcut: "Local AI"
echo  ============================================================
echo.
pause
