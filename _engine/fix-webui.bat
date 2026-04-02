@echo off
title Fix Open WebUI
color 0E

echo.
echo  ============================================================
echo    FIXING OPEN WEBUI - localhost:3000
echo  ============================================================
echo.

echo  [1/4] Checking current container status...
echo.
docker ps -a --filter "name=open-webui" --format "ID: {{.ID}}  Status: {{.Status}}  Ports: {{.Ports}}"
echo.

echo  [2/4] Showing last 20 lines of container logs...
echo  (This tells us what went wrong)
echo.
docker logs --tail 20 open-webui 2>&1
echo.
pause

echo  [3/4] Stopping and removing old container...
docker stop open-webui >nul 2>&1
docker rm open-webui >nul 2>&1
echo  [OK] Old container removed.
echo.

echo  [4/4] Creating fresh container (showing full output this time)...
echo.
docker run -d ^
    -p 3000:8080 ^
    --add-host=host.docker.internal:host-gateway ^
    -e OLLAMA_BASE_URL=http://host.docker.internal:11434 ^
    -e WEBUI_AUTH=False ^
    -v open-webui:/app/backend/data ^
    --name open-webui ^
    --restart unless-stopped ^
    ghcr.io/open-webui/open-webui:main

if errorlevel 1 (
    echo.
    echo  [ERROR] Docker run failed. Error shown above.
    echo.
    pause
    exit /b 1
)

echo.
echo  [OK] Container created. Waiting 60 seconds for it to start...
echo       (Open WebUI takes about 60 seconds on first boot)
echo.
timeout /t 10 /nobreak >nul
echo  10 seconds...
timeout /t 10 /nobreak >nul
echo  20 seconds...
timeout /t 10 /nobreak >nul
echo  30 seconds...
timeout /t 10 /nobreak >nul
echo  40 seconds...
timeout /t 10 /nobreak >nul
echo  50 seconds...
timeout /t 10 /nobreak >nul
echo  60 seconds - opening browser...
echo.

start http://localhost:3000

echo  ============================================================
echo    If the browser shows the chat interface - SUCCESS!
echo    If it still fails, check the logs shown above for errors.
echo  ============================================================
echo.
pause
