@echo off
setlocal EnableDelayedExpansion
title NeuralBox - Smoke Test
color 0B

:: ============================================================
:: NeuralBox Smoke Test
:: Validates critical paths without requiring a full install.
:: Run after install or after making changes to verify nothing broke.
:: ============================================================

set "ROOT=%~dp0..\.."
set PASS=0
set FAIL=0
set WARN=0

echo.
echo  ============================================================
echo    NeuralBox Smoke Test
echo    %date% %time%
echo  ============================================================
echo.

:: ----  Helper macros -----------------------------------------
:: Usage: call :check_file "path" "label"
:: Usage: call :check_port port label
:: Usage: call :check_cmd "cmd" label

goto :tests

:check_file
    if exist "%~1" (
        echo  [PASS] File exists: %~2
        set /a PASS+=1
    ) else (
        echo  [FAIL] File missing: %~2 (%~1)
        set /a FAIL+=1
    )
    exit /b

:check_port
    curl -s --max-time 3 -o nul -w "%%{http_code}" http://localhost:%~1 > "%TEMP%\st_%~1.txt" 2>nul
    set /p ST_CODE=<"%TEMP%\st_%~1.txt"
    if "!ST_CODE!"=="200" (
        echo  [PASS] Port %~1 (%~2^) - HTTP 200
        set /a PASS+=1
    ) else if "!ST_CODE!"=="302" (
        echo  [PASS] Port %~1 (%~2^) - HTTP 302 redirect
        set /a PASS+=1
    ) else if "!ST_CODE!"=="400" (
        echo  [PASS] Port %~1 (%~2^) - HTTP 400 (service running)
        set /a PASS+=1
    ) else (
        echo  [FAIL] Port %~1 (%~2^) - HTTP !ST_CODE! (not responding)
        set /a FAIL+=1
    )
    exit /b

:check_cmd
    where %~1 >nul 2>&1
    if not errorlevel 1 (
        echo  [PASS] Command found: %~2
        set /a PASS+=1
    ) else (
        echo  [FAIL] Command not found: %~2
        set /a FAIL+=1
    )
    exit /b

:check_api
    :: %1=url %2=label %3=expected_string_in_response
    curl -s --max-time 5 "%~1" > "%TEMP%\st_api.txt" 2>nul
    findstr /i "%~3" "%TEMP%\st_api.txt" >nul 2>&1
    if not errorlevel 1 (
        echo  [PASS] API: %~2 (contains "%~3"^)
        set /a PASS+=1
    ) else (
        echo  [FAIL] API: %~2 (missing "%~3"^)
        set /a FAIL+=1
    )
    exit /b

:: ===========================================================
:tests
:: ===========================================================

echo  --- FILE STRUCTURE CHECKS ---
call :check_file "%ROOT%\start.bat"                              "start.bat"
call :check_file "%ROOT%\_engine\install.bat"                    "_engine/install.bat"
call :check_file "%ROOT%\_engine\install.ps1"                    "_engine/install.ps1"
call :check_file "%ROOT%\_engine\launcher\launch-ai.bat"         "launcher/launch-ai.bat"
call :check_file "%ROOT%\_engine\launcher\stop-ai.bat"           "launcher/stop-ai.bat"
call :check_file "%ROOT%\_engine\launcher\healthcheck.bat"       "launcher/healthcheck.bat"
call :check_file "%ROOT%\_engine\scripts\update-server.ps1"      "scripts/update-server.ps1"
call :check_file "%ROOT%\_engine\scripts\update-logic.ps1"       "scripts/update-logic.ps1"
call :check_file "%ROOT%\hub\hub.js"                             "hub/hub.js"
call :check_file "%ROOT%\hub\storage.js"                         "hub/storage.js"
call :check_file "%ROOT%\hub\efficiency.js"                      "hub/efficiency.js"
call :check_file "%ROOT%\hub\router.js"                          "hub/router.js"
call :check_file "%ROOT%\config\settings.json"                   "config/settings.json"
call :check_file "%ROOT%\_engine\version.json"                   "_engine/version.json"
echo.

echo  --- PREREQUISITE CHECKS ---
call :check_cmd ollama "Ollama"
call :check_cmd docker "Docker"
call :check_cmd node   "Node.js"
echo.

echo  --- SERVICE HEALTH CHECKS ---
call :check_port 11434 "Ollama"
call :check_port 3000  "Open WebUI"
call :check_port 8080  "NeuralBox Hub"

:: Check update server (optional)
curl -s --max-time 3 -o nul -w "%%{http_code}" http://localhost:9999/api/health > "%TEMP%\st_9999.txt" 2>nul
set /p ST_9999=<"%TEMP%\st_9999.txt"
if "!ST_9999!"=="200" (
    echo  [PASS] Port 9999 (Update Server^) - HTTP 200
    set /a PASS+=1
) else (
    echo  [WARN] Port 9999 (Update Server^) - not running (non-critical)
    set /a WARN+=1
)

:: Check OpenClaw (optional)
curl -s --max-time 2 -o nul -w "%%{http_code}" http://localhost:18789 > "%TEMP%\st_18789.txt" 2>nul
set /p ST_18789=<"%TEMP%\st_18789.txt"
if "!ST_18789!"=="200" (
    echo  [PASS] Port 18789 (OpenClaw^) - HTTP 200
    set /a PASS+=1
) else (
    echo  [WARN] Port 18789 (OpenClaw^) - not running (optional)
    set /a WARN+=1
)
echo.

echo  --- API ENDPOINT CHECKS ---
call :check_api "http://localhost:8080/api/status"   "Hub /api/status"   "ollama"
call :check_api "http://localhost:8080/api/settings" "Hub /api/settings" "primary_model"
call :check_api "http://localhost:8080/api/profiles" "Hub /api/profiles" "Local Only"
call :check_api "http://localhost:11434/api/tags"    "Ollama /api/tags"  "models"
echo.

echo  --- SECURITY CHECKS ---
:: Hub should reject write from external origin
curl -s --max-time 3 -H "Origin: http://evil.example.com" -X POST -d "{}" http://localhost:8080/api/settings > "%TEMP%\st_sec.txt" 2>nul
findstr /i "forbidden" "%TEMP%\st_sec.txt" >nul 2>&1
if not errorlevel 1 (
    echo  [PASS] Hub rejects cross-origin POST (returns forbidden^)
    set /a PASS+=1
) else (
    echo  [FAIL] Hub did NOT reject cross-origin POST - CORS not enforced
    set /a FAIL+=1
)

:: Update server should reject write from external origin
curl -s --max-time 3 -H "Origin: http://evil.example.com" -X POST http://localhost:9999/api/update > "%TEMP%\st_sec2.txt" 2>nul
findstr /i "forbidden" "%TEMP%\st_sec2.txt" >nul 2>&1
if not errorlevel 1 (
    echo  [PASS] Update server rejects cross-origin POST
    set /a PASS+=1
) else (
    if "!ST_9999!"=="200" (
        echo  [FAIL] Update server did NOT reject cross-origin POST
        set /a FAIL+=1
    ) else (
        echo  [WARN] Update server not running - security check skipped
        set /a WARN+=1
    )
)

:: Docker port should be bound to 127.0.0.1 only
docker inspect open-webui 2>nul | findstr /i "HostIp" > "%TEMP%\st_docker.txt" 2>nul
findstr /i "0.0.0.0" "%TEMP%\st_docker.txt" >nul 2>&1
if not errorlevel 1 (
    echo  [FAIL] Open WebUI Docker port bound to 0.0.0.0 (should be 127.0.0.1^)
    set /a FAIL+=1
) else (
    findstr /i "127.0.0.1" "%TEMP%\st_docker.txt" >nul 2>&1
    if not errorlevel 1 (
        echo  [PASS] Open WebUI Docker port bound to 127.0.0.1
        set /a PASS+=1
    ) else (
        echo  [WARN] Could not verify Docker port binding
        set /a WARN+=1
    )
)
echo.

echo  --- STOP FLOW CHECK ---
echo  [INFO] Testing stop script path resolution...
if exist "%ROOT%\_engine\launcher\stop-ai.bat" (
    :: Verify log path in stop script points to correct location
    findstr /i "..\..\logs" "%ROOT%\_engine\launcher\stop-ai.bat" >nul 2>&1
    if not errorlevel 1 (
        echo  [PASS] stop-ai.bat log path is correct
        set /a PASS+=1
    ) else (
        echo  [FAIL] stop-ai.bat may have wrong log path
        set /a FAIL+=1
    )
)
echo.

echo  --- PATH RESOLUTION CHECKS ---
findstr /i "_engine\\scripts\\update-logic" "%ROOT%\_engine\scripts\update-server.ps1" >nul 2>&1
if not errorlevel 1 (
    echo  [PASS] update-server.ps1 has correct logic script path
    set /a PASS+=1
) else (
    echo  [FAIL] update-server.ps1 may have wrong logic script path
    set /a FAIL+=1
)
echo.

echo  ============================================================
echo    RESULTS:  %PASS% PASSED  /  %FAIL% FAILED  /  %WARN% WARNINGS
if %FAIL% EQU 0 (
    if %WARN% EQU 0 (
        echo    OVERALL:  ALL CHECKS PASSED
    ) else (
        echo    OVERALL:  PASSED with %WARN% warnings (optional services^)
    )
) else (
    echo    OVERALL:  %FAIL% CHECK(S^) FAILED - see above
)
echo  ============================================================
echo.
pause
endlocal
