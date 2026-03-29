@echo off
title Local AI - Restarting Services
color 0E

:: ============================================================
:: LOCAL AI - RESTART SERVICES
:: Stops everything and re-launches.
:: ============================================================

echo.
echo  ============================================================
echo    LOCAL AI  -  Restarting...
echo  ============================================================
echo.

echo  Stopping services...
call "%~dp0stop-ai.bat"

echo.
echo  Waiting 3 seconds before restarting...
timeout /t 3 /nobreak >nul

echo  Starting services...
call "%~dp0launch-ai.bat"
