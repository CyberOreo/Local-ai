@echo off
title NeuralBox Setup
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_engine\install.ps1" -ProjectRoot "%~dp0"
pause
