# ============================================================
# update-logic.ps1
# Called by update-server.ps1 in a background job.
# Performs all update steps and writes progress to StatusFile.
# ============================================================

param(
    [string]$ProjectRoot,
    [string]$StatusFile
)

$PRIMARY_MODEL  = "qwen3.5:9b"
$BACKUP_MODEL   = "qwen3.5:4b"
$WEBUI_IMAGE    = "ghcr.io/open-webui/open-webui:main"
$CONTAINER      = "open-webui"
$OLLAMA_PORT    = 11434
$WEBUI_PORT     = 3000

# Load .env overrides if present
$envFile = Join-Path $ProjectRoot "config\.env"
if (Test-Path $envFile) {
    Get-Content $envFile | Where-Object { $_ -notmatch '^\s*#' -and $_ -match '=' } | ForEach-Object {
        $k, $v = $_ -split '=', 2
        Set-Variable -Name $k.Trim() -Value $v.Trim() -Scope Script -ErrorAction SilentlyContinue
    }
}

$steps   = [System.Collections.Generic.List[string]]::new()
$errors  = [System.Collections.Generic.List[string]]::new()

# -- Helpers --------------------------------------------------

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
            $null = Invoke-WebRequest -Uri "http://localhost:$OLLAMA_PORT/api/tags" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            return $true
        } catch {}
        Start-Sleep 3
        $waited += 3
    }
    return $false
}

# -- Start ----------------------------------------------------

try {

Add-Step "Starting update..."

# -- STEP 1: Stop services ------------------------------------
Add-Step "Stopping services..."
& docker stop $CONTAINER 2>$null | Out-Null
& taskkill /F /IM ollama.exe /T 2>$null | Out-Null
Start-Sleep 3
Add-Step "Services stopped."

# -- STEP 2: Update Ollama ------------------------------------
Add-Step "Updating Ollama runtime..."
try {
    $installer = Join-Path $env:TEMP "OllamaSetup.exe"
    Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" `
        -OutFile $installer -UseBasicParsing -TimeoutSec 60
    Start-Process -FilePath $installer -ArgumentList "/S" -Wait -ErrorAction Stop
    # Refresh PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH","User")
    Add-Step "Ollama updated."
} catch {
    Add-Error "Ollama update failed (non-critical): $_"
}

# -- STEP 3: Update Open WebUI image --------------------------
Add-Step "Updating Open WebUI image (downloading only changed layers)..."
try {
    # Make sure Docker daemon is running
    $dockerOk = $false
    $info = & docker info 2>&1
    if ($LASTEXITCODE -eq 0) { $dockerOk = $true }

    if (-not $dockerOk) {
        Add-Step "Starting Docker Desktop..."
        $dockerExe = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
        if (Test-Path $dockerExe) {
            Start-Process $dockerExe
            $waited = 0
            while ($waited -lt 60) {
                Start-Sleep 5; $waited += 5
                $info = & docker info 2>&1
                if ($LASTEXITCODE -eq 0) { $dockerOk = $true; break }
            }
        }
    }

    if ($dockerOk) {
        & docker pull $WEBUI_IMAGE
        if ($LASTEXITCODE -eq 0) {
            Add-Step "Removing old container (chat history is in a volume  -  safe)..."
            & docker rm $CONTAINER 2>$null | Out-Null
            Add-Step "Recreating container with latest image..."
            & docker run -d `
                -p "${WEBUI_PORT}:8080" `
                --add-host=host.docker.internal:host-gateway `
                -e "OLLAMA_BASE_URL=http://host.docker.internal:${OLLAMA_PORT}" `
                -e "WEBUI_AUTH=False" `
                -v "open-webui:/app/backend/data" `
                --name $CONTAINER `
                --restart unless-stopped `
                $WEBUI_IMAGE 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Add-Step "Open WebUI updated. Chat history preserved."
                # Re-install skill packages (lost when container is recreated)
                Add-Step "Re-installing skill packages into updated container..."
                $pkgResult = & docker exec $CONTAINER pip install --quiet --no-warn-script-location `
                    youtube-transcript-api requests beautifulsoup4 pypdf python-docx openpyxl lxml 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Add-Step "Skill packages re-installed."
                } else {
                    Add-Error "Skill package re-install failed (non-critical): $pkgResult"
                }
            } else {
                Add-Error "Failed to recreate container  -  run start.bat to recover."
            }
        } else {
            Add-Error "docker pull failed  -  keeping existing image."
        }
    } else {
        Add-Error "Docker not available  -  WebUI update skipped."
    }
} catch {
    Add-Error "WebUI update error: $_"
}

# -- STEP 4: Start Ollama for model updates -------------------
Add-Step "Starting Ollama for model updates..."
Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
$ready = Wait-OllamaReady -timeout 30
if (-not $ready) {
    Add-Error "Ollama did not start in time  -  model updates skipped."
    Set-Status "Update complete with warnings. Restart the app." "complete"
    exit 0
}
Add-Step "Ollama ready."

# -- STEP 5: Update primary model -----------------------------
Add-Step "Updating $PRIMARY_MODEL (smart delta  -  0 bytes if unchanged)..."
& ollama pull $PRIMARY_MODEL
if ($LASTEXITCODE -eq 0) {
    Add-Step "$PRIMARY_MODEL is up to date."
} else {
    Add-Error "$PRIMARY_MODEL update failed  -  existing version kept."
}

# -- STEP 6: Update backup model ------------------------------
Add-Step "Updating $BACKUP_MODEL..."
& ollama pull $BACKUP_MODEL
if ($LASTEXITCODE -eq 0) {
    Add-Step "$BACKUP_MODEL is up to date."
} else {
    Add-Error "$BACKUP_MODEL update failed  -  existing version kept."
}

# -- DONE -----------------------------------------------------
$errCount = $errors.Count
if ($errCount -eq 0) {
    Set-Status "Update complete! Everything is up to date. Refresh the page." "complete"
} else {
    Set-Status "Update complete with $errCount warning(s). Check the steps list." "complete"
}

} catch {
    Add-Error "Unexpected error: $_"
    Set-Status "Update failed: $_. Run update.bat manually." "error"
}
