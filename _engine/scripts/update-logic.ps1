# ============================================================
# update-logic.ps1
# Called by update-server.ps1 in a background job.
# Performs all update steps and writes progress to StatusFile.
#
# SAFETY MODEL:
#   - Reads all version targets from _engine/version.json (single source)
#   - Checks if components are already up to date before downloading
#   - Verifies pulled image before recreating container (rollback-friendly)
#   - Does not remove old container until new image is confirmed good
#   - On container creation failure, attempts rollback to previous image
# ============================================================

param(
    [string]$ProjectRoot,
    [string]$StatusFile
)

# ── Load version config (single source of truth) ─────────────
$PRIMARY_MODEL = "qwen3.5:9b"
$BACKUP_MODEL  = "qwen3.5:4b"
$WEBUI_IMAGE   = "ghcr.io/open-webui/open-webui:v0.6.5"

$versionFile = Join-Path $ProjectRoot "_engine\version.json"
if (Test-Path $versionFile) {
    try {
        $vCfg = Get-Content $versionFile -Raw | ConvertFrom-Json
        if ($vCfg.webui_image)   { $WEBUI_IMAGE   = $vCfg.webui_image }
        if ($vCfg.primary_model) { $PRIMARY_MODEL = $vCfg.primary_model }
        if ($vCfg.backup_model)  { $BACKUP_MODEL  = $vCfg.backup_model }
    } catch {
        # version.json malformed — use defaults
    }
}

$CONTAINER   = "open-webui"
$OLLAMA_PORT = 11434
$WEBUI_PORT  = 3000

# Load .env overrides (ports may differ)
$envFile = Join-Path $ProjectRoot "config\.env"
if (Test-Path $envFile) {
    Get-Content $envFile | Where-Object { $_ -notmatch '^\s*#' -and $_ -match '=' } | ForEach-Object {
        $k, $v = $_ -split '=', 2
        Set-Variable -Name $k.Trim() -Value $v.Trim() -Scope Script -ErrorAction SilentlyContinue
    }
}

$steps  = [System.Collections.Generic.List[string]]::new()
$errors = [System.Collections.Generic.List[string]]::new()

# ── Helpers ───────────────────────────────────────────────────

function Set-Status([string]$msg, [string]$state = "running") {
    $obj = [ordered]@{
        status    = $state
        message   = $msg
        timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        steps     = $steps.ToArray()
        errors    = $errors.ToArray()
    }
    $obj | ConvertTo-Json | Set-Content -Path $StatusFile -Encoding UTF8 -Force
}

function Add-Step([string]$msg) {
    $steps.Add("[$(Get-Date -Format 'HH:mm:ss')] $msg")
    Set-Status $msg
}

function Add-Error([string]$msg) {
    $errors.Add($msg)
    $steps.Add("[$(Get-Date -Format 'HH:mm:ss')] WARN: $msg")
    Set-Status $msg
}

function Wait-OllamaReady([int]$timeout = 30) {
    $waited = 0
    while ($waited -lt $timeout) {
        try {
            $null = Invoke-WebRequest -Uri "http://localhost:$OLLAMA_PORT/api/tags" `
                -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            return $true
        } catch {}
        Start-Sleep 3; $waited += 3
    }
    return $false
}

function Get-ImageId([string]$nameOrId) {
    try {
        $id = & docker inspect $nameOrId --format "{{.Id}}" 2>$null
        if ($LASTEXITCODE -eq 0) { return $id.Trim() }
    } catch {}
    return $null
}

function Get-ContainerImageId([string]$containerName) {
    try {
        $id = & docker inspect $containerName --format "{{.Image}}" 2>$null
        if ($LASTEXITCODE -eq 0) { return $id.Trim() }
    } catch {}
    return $null
}

function Test-ContainerRunning([string]$name) {
    $state = & docker inspect $name --format "{{.State.Running}}" 2>$null
    return ($LASTEXITCODE -eq 0 -and $state.Trim() -eq "true")
}

function Ensure-DockerRunning {
    $info = & docker info 2>&1
    if ($LASTEXITCODE -eq 0) { return $true }

    Add-Step "Starting Docker Desktop..."
    $dockerExe = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    if (-not (Test-Path $dockerExe)) {
        $dockerExe = "$env:LOCALAPPDATA\Programs\Docker\Docker\Docker Desktop.exe"
    }
    if (Test-Path $dockerExe) {
        Start-Process $dockerExe
        $waited = 0
        while ($waited -lt 60) {
            Start-Sleep 5; $waited += 5
            $info = & docker info 2>&1
            if ($LASTEXITCODE -eq 0) { return $true }
        }
    }
    return $false
}

# ── Main update flow ─────────────────────────────────────────

try {

Add-Step "Update started. Reading targets from version.json..."
Add-Step "WebUI image: $WEBUI_IMAGE  |  Primary: $PRIMARY_MODEL  |  Backup: $BACKUP_MODEL"

# ── STEP 1: Stop services ─────────────────────────────────────
Add-Step "Stopping services for update..."
& docker stop $CONTAINER 2>$null | Out-Null
& taskkill /F /IM ollama.exe /T 2>$null | Out-Null
Start-Sleep 3
Add-Step "Services stopped."

# ── STEP 2: Update Ollama ─────────────────────────────────────
Add-Step "Checking Ollama update..."
try {
    # Record current version
    $currentOllamaVer = & ollama --version 2>$null
    Add-Step "Current Ollama: $currentOllamaVer"

    $ollamaUrl = $null
    # Read download URL from version.json
    if ($vCfg -and $vCfg.ollama_download_url) {
        $ollamaUrl = $vCfg.ollama_download_url
    } else {
        $ollamaUrl = "https://ollama.com/download/OllamaSetup.exe"
    }

    $installer = Join-Path $env:TEMP "OllamaSetup.exe"
    Add-Step "Downloading Ollama from $ollamaUrl..."
    Invoke-WebRequest -Uri $ollamaUrl -OutFile $installer -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
    Add-Step "Running Ollama installer (silent)..."
    Start-Process -FilePath $installer -ArgumentList "/S" -Wait -ErrorAction Stop

    # Refresh PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH","User")

    $newOllamaVer = & ollama --version 2>$null
    Add-Step "Ollama updated: $currentOllamaVer → $newOllamaVer"
} catch {
    Add-Error "Ollama update failed (non-critical, keeping existing): $_"
}

# ── STEP 3: Update Open WebUI image ──────────────────────────
Add-Step "Checking Open WebUI update ($WEBUI_IMAGE)..."
try {
    $dockerOk = Ensure-DockerRunning
    if (-not $dockerOk) {
        Add-Error "Docker not available — WebUI update skipped."
    } else {
        # Record the current container's image ID before touching anything
        $oldImageId = Get-ContainerImageId $CONTAINER
        if ($oldImageId) { Add-Step "Current container image ID: $($oldImageId.Substring(0,16))..." }

        # Pull the new image
        Add-Step "Pulling $WEBUI_IMAGE (only changed layers downloaded)..."
        & docker pull $WEBUI_IMAGE 2>&1 | ForEach-Object { $steps.Add("[$(Get-Date -Format 'HH:mm:ss')]   $_") }
        if ($LASTEXITCODE -ne 0) {
            Add-Error "docker pull $WEBUI_IMAGE failed — keeping existing container. Run start.bat to recover."
            # Try to restart the old container
            & docker start $CONTAINER 2>$null | Out-Null
        } else {
            # Verify the pulled image actually exists and is usable
            $newImageId = Get-ImageId $WEBUI_IMAGE
            if (-not $newImageId) {
                Add-Error "Pulled image could not be verified — keeping existing container."
                & docker start $CONTAINER 2>$null | Out-Null
            } elseif ($newImageId -eq $oldImageId) {
                Add-Step "Open WebUI is already up to date (image unchanged). Restarting container."
                & docker start $CONTAINER 2>$null | Out-Null
            } else {
                Add-Step "New image verified ($($newImageId.Substring(0,16))...). Recreating container..."

                # Remove old container — chat history is in the open-webui Docker volume
                & docker rm $CONTAINER 2>$null | Out-Null

                # Create new container with secure port binding
                & docker run -d `
                    -p "127.0.0.1:${WEBUI_PORT}:8080" `
                    --add-host=host.docker.internal:host-gateway `
                    -e "OLLAMA_BASE_URL=http://host.docker.internal:${OLLAMA_PORT}" `
                    -e "WEBUI_AUTH=False" `
                    -v "open-webui:/app/backend/data" `
                    --name $CONTAINER `
                    --restart unless-stopped `
                    $WEBUI_IMAGE 2>&1 | Out-Null

                if ($LASTEXITCODE -ne 0) {
                    Add-Error "Failed to create new container. Attempting rollback to previous image..."
                    # Rollback: try to recreate with the old image ID (if we have it)
                    if ($oldImageId) {
                        & docker run -d `
                            -p "127.0.0.1:${WEBUI_PORT}:8080" `
                            --add-host=host.docker.internal:host-gateway `
                            -e "OLLAMA_BASE_URL=http://host.docker.internal:${OLLAMA_PORT}" `
                            -e "WEBUI_AUTH=False" `
                            -v "open-webui:/app/backend/data" `
                            --name $CONTAINER `
                            --restart unless-stopped `
                            $oldImageId 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Add-Step "Rollback successful — running previous image. Chat history preserved."
                        } else {
                            Add-Error "Rollback also failed. Run start.bat to recover the container."
                        }
                    } else {
                        Add-Error "No previous image ID recorded — cannot rollback. Run start.bat to recover."
                    }
                } else {
                    Add-Step "Open WebUI container recreated with new image."

                    # Re-install skill packages into fresh container (wait briefly for it to start)
                    Start-Sleep 5
                    Add-Step "Re-installing skill packages..."
                    $pkgResult = & docker exec $CONTAINER pip install --quiet --no-warn-script-location `
                        youtube-transcript-api requests beautifulsoup4 pypdf python-docx openpyxl lxml 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Add-Step "Skill packages re-installed."
                    } else {
                        Add-Error "Skill package install failed (non-critical): $pkgResult"
                    }

                    # Verify container is healthy
                    Start-Sleep 3
                    if (Test-ContainerRunning $CONTAINER) {
                        Add-Step "Container health check: PASS (container is running)."
                    } else {
                        Add-Error "Container health check: container not running after creation. Check docker logs $CONTAINER"
                    }
                }
            }
        }
    }
} catch {
    Add-Error "WebUI update error: $_"
}

# ── STEP 4: Start Ollama for model updates ────────────────────
Add-Step "Starting Ollama for model updates..."
Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
$ready = Wait-OllamaReady -timeout 30
if (-not $ready) {
    Add-Error "Ollama did not start in time — model updates skipped."
    Set-Status "Update complete with warnings. Run start.bat to finish." "complete"
    exit 0
}
Add-Step "Ollama ready."

# ── STEP 5: Update primary model ─────────────────────────────
Add-Step "Checking $PRIMARY_MODEL (smart delta — 0 bytes if unchanged)..."
& ollama pull $PRIMARY_MODEL 2>&1 | ForEach-Object { if ($_) { $steps.Add("[$(Get-Date -Format 'HH:mm:ss')]   $_") } }
if ($LASTEXITCODE -eq 0) {
    Add-Step "$PRIMARY_MODEL is up to date."
} else {
    Add-Error "$PRIMARY_MODEL update failed — existing version kept."
}

# ── STEP 6: Update backup model ──────────────────────────────
Add-Step "Checking $BACKUP_MODEL..."
& ollama pull $BACKUP_MODEL 2>&1 | ForEach-Object { if ($_) { $steps.Add("[$(Get-Date -Format 'HH:mm:ss')]   $_") } }
if ($LASTEXITCODE -eq 0) {
    Add-Step "$BACKUP_MODEL is up to date."
} else {
    Add-Error "$BACKUP_MODEL update failed — existing version kept."
}

# ── Done ──────────────────────────────────────────────────────
$errCount = $errors.Count
if ($errCount -eq 0) {
    Set-Status "Update complete. Everything is up to date. Refresh the page if needed." "complete"
} else {
    Set-Status "Update complete with $errCount warning(s). Check the progress log." "complete"
}

} catch {
    Add-Error "Unexpected error: $_"
    Set-Status "Update failed: $_. Run _engine\update.bat manually." "error"
}
