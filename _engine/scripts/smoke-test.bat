@echo off
setlocal EnableDelayedExpansion
title NeuralBox - Smoke Test
color 0B

:: ============================================================
:: NeuralBox Smoke Test
:: Validates critical paths without requiring a full reinstall.
:: Run after install or changes to verify nothing broke.
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

goto :tests

:check_file
    if exist "%~1" (
        echo  [PASS] File exists: %~2
        set /a PASS+=1
    ) else (
        echo  [FAIL] File missing: %~2 ^(%~1^)
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

:check_port
    curl -s --max-time 3 -o nul -w "%%{http_code}" http://localhost:%~1 > "%TEMP%\st_%~1.txt" 2>nul
    set /p ST_CODE=<"%TEMP%\st_%~1.txt"
    if "!ST_CODE!"=="200" (
        echo  [PASS] Port %~1 ^(%~2^) - HTTP 200
        set /a PASS+=1
    ) else if "!ST_CODE!"=="302" (
        echo  [PASS] Port %~1 ^(%~2^) - HTTP 302 redirect
        set /a PASS+=1
    ) else if "!ST_CODE!"=="400" (
        echo  [PASS] Port %~1 ^(%~2^) - HTTP 400 ^(service alive^)
        set /a PASS+=1
    ) else (
        echo  [FAIL] Port %~1 ^(%~2^) - HTTP !ST_CODE! ^(not responding^)
        set /a FAIL+=1
    )
    exit /b

:check_api
    curl -s --max-time 5 "%~1" > "%TEMP%\st_api.txt" 2>nul
    findstr /i "%~3" "%TEMP%\st_api.txt" >nul 2>&1
    if not errorlevel 1 (
        echo  [PASS] API: %~2 ^(contains "%~3"^)
        set /a PASS+=1
    ) else (
        echo  [FAIL] API: %~2 ^(missing "%~3"^)
        set /a FAIL+=1
    )
    exit /b

:: ===========================================================
:tests
:: ===========================================================

echo  --- FILE STRUCTURE ---
call :check_file "%ROOT%\start.bat"                              "start.bat"
call :check_file "%ROOT%\_engine\install.bat"                    "_engine/install.bat"
call :check_file "%ROOT%\_engine\install.ps1"                    "_engine/install.ps1"
call :check_file "%ROOT%\_engine\version.json"                   "_engine/version.json"
call :check_file "%ROOT%\_engine\launcher\launch-ai.bat"         "_engine/launcher/launch-ai.bat"
call :check_file "%ROOT%\_engine\launcher\stop-ai.bat"           "_engine/launcher/stop-ai.bat"
call :check_file "%ROOT%\_engine\launcher\healthcheck.bat"       "_engine/launcher/healthcheck.bat"
call :check_file "%ROOT%\_engine\scripts\update-server.ps1"      "_engine/scripts/update-server.ps1"
call :check_file "%ROOT%\_engine\scripts\update-logic.ps1"       "_engine/scripts/update-logic.ps1"
call :check_file "%ROOT%\hub\hub.js"                             "hub/hub.js"
call :check_file "%ROOT%\hub\keystore.js"                        "hub/keystore.js"
call :check_file "%ROOT%\hub\storage.js"                         "hub/storage.js"
call :check_file "%ROOT%\hub\efficiency.js"                      "hub/efficiency.js"
call :check_file "%ROOT%\hub\router.js"                          "hub/router.js"
call :check_file "%ROOT%\config\settings.json"                   "config/settings.json"
echo.

echo  --- PREREQUISITES ---
call :check_cmd ollama "Ollama"
call :check_cmd docker "Docker"
call :check_cmd node   "Node.js"
echo.

echo  --- SERVICE HEALTH ---
call :check_port 11434 "Ollama"
call :check_port 3000  "Open WebUI"
call :check_port 8080  "NeuralBox Hub"

curl -s --max-time 3 -o nul -w "%%{http_code}" http://localhost:9999/api/health > "%TEMP%\st_9999.txt" 2>nul
set /p ST_9999=<"%TEMP%\st_9999.txt"
if "!ST_9999!"=="200" (
    echo  [PASS] Port 9999 ^(Update Server^) - HTTP 200
    set /a PASS+=1
) else (
    echo  [WARN] Port 9999 ^(Update Server^) - not running ^(non-critical^)
    set /a WARN+=1
)

curl -s --max-time 2 -o nul -w "%%{http_code}" http://localhost:18789 > "%TEMP%\st_18789.txt" 2>nul
set /p ST_18789=<"%TEMP%\st_18789.txt"
if "!ST_18789!"=="200" (
    echo  [PASS] Port 18789 ^(OpenClaw^) - HTTP 200
    set /a PASS+=1
) else (
    echo  [WARN] Port 18789 ^(OpenClaw^) - not running ^(optional^)
    set /a WARN+=1
)
echo.

echo  --- API ENDPOINTS ---
call :check_api "http://localhost:8080/api/status"   "Hub /api/status"   "ollama"
call :check_api "http://localhost:8080/api/settings" "Hub /api/settings" "primary_model"
call :check_api "http://localhost:8080/api/profiles" "Hub /api/profiles" "Local Only"
call :check_api "http://localhost:11434/api/tags"    "Ollama /api/tags"  "models"
echo.

echo  --- SECURITY: ORIGIN + TOKEN AUTH ---

:: 1. Hub must reject POST from external origin (no token)
curl -s --max-time 3 -H "Origin: http://evil.example.com" -X POST -d "{}" ^
    http://localhost:8080/api/settings > "%TEMP%\st_cors.txt" 2>nul
findstr /i "forbidden\|authentication" "%TEMP%\st_cors.txt" >nul 2>&1
if not errorlevel 1 (
    echo  [PASS] Hub rejects cross-origin POST ^(returns forbidden^)
    set /a PASS+=1
) else (
    echo  [FAIL] Hub did NOT reject cross-origin POST
    set /a FAIL+=1
)

:: 2. Hub must reject POST from local origin WITHOUT token
curl -s --max-time 3 -H "Origin: http://localhost:8080" -X POST -d "{}" ^
    http://localhost:8080/api/settings > "%TEMP%\st_noauth.txt" 2>nul
findstr /i "forbidden\|authentication" "%TEMP%\st_noauth.txt" >nul 2>&1
if not errorlevel 1 (
    echo  [PASS] Hub rejects local-origin POST without token
    set /a PASS+=1
) else (
    echo  [FAIL] Hub allowed local-origin POST without token ^(token auth not enforced^)
    set /a FAIL+=1
)

:: 3. Hub must accept POST with valid token
set HUB_TOKEN=
if exist "%USERPROFILE%\.neuralbox\hub-token" (
    set /p HUB_TOKEN=<"%USERPROFILE%\.neuralbox\hub-token"
)
if defined HUB_TOKEN (
    curl -s --max-time 3 -H "X-Hub-Token: !HUB_TOKEN!" -H "Content-Type: application/json" ^
        -X POST -d "{}" http://localhost:8080/api/settings > "%TEMP%\st_auth.txt" 2>nul
    :: A 200 or settings-related response means auth accepted
    findstr /i "forbidden\|authentication" "%TEMP%\st_auth.txt" >nul 2>&1
    if not errorlevel 1 (
        echo  [FAIL] Hub rejected valid token ^(token auth broken^)
        set /a FAIL+=1
    ) else (
        echo  [PASS] Hub accepts requests with valid X-Hub-Token
        set /a PASS+=1
    )
) else (
    echo  [WARN] hub-token file not found - hub not running or token not created
    set /a WARN+=1
)

:: 4. Update server must reject write from external origin
curl -s --max-time 3 -H "Origin: http://evil.example.com" -X POST ^
    http://localhost:9999/api/update > "%TEMP%\st_upd.txt" 2>nul
findstr /i "forbidden" "%TEMP%\st_upd.txt" >nul 2>&1
if not errorlevel 1 (
    echo  [PASS] Update server rejects cross-origin POST
    set /a PASS+=1
) else (
    if "!ST_9999!"=="200" (
        echo  [FAIL] Update server did NOT reject cross-origin POST
        set /a FAIL+=1
    ) else (
        echo  [WARN] Update server not running - CORS check skipped
        set /a WARN+=1
    )
)

:: 5. Docker port must be bound to 127.0.0.1 only
docker inspect open-webui 2>nul | findstr /i "HostIp" > "%TEMP%\st_docker.txt" 2>nul
findstr /i "0.0.0.0" "%TEMP%\st_docker.txt" >nul 2>&1
if not errorlevel 1 (
    echo  [FAIL] open-webui Docker port bound to 0.0.0.0 ^(should be 127.0.0.1^)
    set /a FAIL+=1
) else (
    findstr /i "127.0.0.1" "%TEMP%\st_docker.txt" >nul 2>&1
    if not errorlevel 1 (
        echo  [PASS] open-webui Docker port bound to 127.0.0.1
        set /a PASS+=1
    ) else (
        echo  [WARN] Could not verify Docker port binding
        set /a WARN+=1
    )
)
echo.

echo  --- BUDGET ENFORCEMENT ---
:: Hub /api/stats must return spend info
curl -s --max-time 3 http://localhost:8080/api/stats > "%TEMP%\st_spend.txt" 2>nul
findstr /i "today_usd\|locked\|limit_usd" "%TEMP%\st_spend.txt" >nul 2>&1
if not errorlevel 1 (
    echo  [PASS] Hub /api/stats returns spend info
    set /a PASS+=1
) else (
    echo  [FAIL] Hub /api/stats missing spend fields
    set /a FAIL+=1
)
echo.

echo  --- STOP FLOW ---
if exist "%ROOT%\_engine\launcher\stop-ai.bat" (
    findstr /i "STOP_ERRORS" "%ROOT%\_engine\launcher\stop-ai.bat" >nul 2>&1
    if not errorlevel 1 (
        echo  [PASS] stop-ai.bat verifies service stops
        set /a PASS+=1
    ) else (
        echo  [FAIL] stop-ai.bat does not verify stops
        set /a FAIL+=1
    )
) else (
    echo  [FAIL] stop-ai.bat not found
    set /a FAIL+=1
)
echo.

echo  --- PATH RESOLUTION ---
:: launch-ai.bat must reference version.json for image
findstr /i "version.json" "%ROOT%\_engine\launcher\launch-ai.bat" >nul 2>&1
if not errorlevel 1 (
    echo  [PASS] launch-ai.bat reads image from version.json
    set /a PASS+=1
) else (
    echo  [FAIL] launch-ai.bat has hardcoded Docker image ^(not reading version.json^)
    set /a FAIL+=1
)

:: update-logic.ps1 must read from version.json
findstr /i "version.json" "%ROOT%\_engine\scripts\update-logic.ps1" >nul 2>&1
if not errorlevel 1 (
    echo  [PASS] update-logic.ps1 reads config from version.json
    set /a PASS+=1
) else (
    echo  [FAIL] update-logic.ps1 has hardcoded versions
    set /a FAIL+=1
)

:: update-server.ps1 must have correct logic script path
findstr /i "_engine\\scripts\\update-logic" "%ROOT%\_engine\scripts\update-server.ps1" >nul 2>&1
if not errorlevel 1 (
    echo  [PASS] update-server.ps1 has correct logic script path
    set /a PASS+=1
) else (
    echo  [FAIL] update-server.ps1 may have wrong logic script path
    set /a FAIL+=1
)

:: stop-ai.bat log path must be correct
findstr /i "..\..\logs" "%ROOT%\_engine\launcher\stop-ai.bat" >nul 2>&1
if not errorlevel 1 (
    echo  [PASS] stop-ai.bat log path is correct
    set /a PASS+=1
) else (
    echo  [FAIL] stop-ai.bat may have wrong log path
    set /a FAIL+=1
)

:: start.bat must NOT do complex install detection (flag only)
findstr /i "ALREADY_INSTALLED" "%ROOT%\start.bat" >nul 2>&1
if not errorlevel 1 (
    echo  [FAIL] start.bat still has multi-check install detection ^(should be flag-only^)
    set /a FAIL+=1
) else (
    echo  [PASS] start.bat uses simple flag-only install detection
    set /a PASS+=1
)

:: hub.js must have token auth
findstr /i "HUB_TOKEN\|validateAuth\|nb_session" "%ROOT%\hub\hub.js" >nul 2>&1
if not errorlevel 1 (
    echo  [PASS] hub.js has token auth
    set /a PASS+=1
) else (
    echo  [FAIL] hub.js missing token auth
    set /a FAIL+=1
)
echo.

echo  ============================================================
echo    RESULTS:  %PASS% PASSED  /  %FAIL% FAILED  /  %WARN% WARNINGS
if %FAIL% EQU 0 (
    if %WARN% EQU 0 (
        echo    OVERALL:  ALL CHECKS PASSED
    ) else (
        echo    OVERALL:  PASSED with %WARN% warnings ^(optional services^)
    )
) else (
    echo    OVERALL:  %FAIL% CHECK^(S^) FAILED - see above
)
echo  ============================================================
echo.
pause
endlocal
