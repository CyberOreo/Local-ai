# ============================================================
# Local AI - Main Installer Script
# install.ps1
#
# Called by install.bat. Do not run this file directly unless
# you know what you are doing.
# ============================================================

param(
    [string]$ProjectRoot = $PSScriptRoot
)

# Normalize project root path
$ProjectRoot = $ProjectRoot.TrimEnd('\').TrimEnd('/')
$LogDir      = Join-Path $ProjectRoot "logs"
$LogFile     = Join-Path $LogDir "install.log"
$ConfigDir   = Join-Path $ProjectRoot "config"

# ---- Helpers ------------------------------------------------

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    switch ($Level) {
        "OK"    { Write-Host "  [OK] $Message" -ForegroundColor Green }
        "WARN"  { Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
        "ERROR" { Write-Host "  [ERROR] $Message" -ForegroundColor Red }
        "INFO"  { Write-Host "  [INFO] $Message" -ForegroundColor Cyan }
        "STEP"  { Write-Host "`n  >>> $Message" -ForegroundColor White }
        default { Write-Host "  $Message" }
    }
}

function Wait-ForPort {
    param([string]$Url, [int]$TimeoutSeconds = 90, [string]$ServiceName = "Service")
    Write-Log "Waiting for $ServiceName to be ready at $Url ..." "INFO"
    $elapsed = 0
    while ($elapsed -lt $TimeoutSeconds) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
            if ($response.StatusCode -lt 500) {
                Write-Log "$ServiceName is ready." "OK"
                return $true
            }
        } catch {}
        Start-Sleep -Seconds 3
        $elapsed += 3
        Write-Host "    ...waiting ($elapsed/$TimeoutSeconds sec)" -ForegroundColor DarkGray
    }
    Write-Log "$ServiceName did not respond within $TimeoutSeconds seconds." "ERROR"
    return $false
}

# ---- Start --------------------------------------------------

# Ensure log directory exists
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Cyan
Write-Host "    LOCAL AI INSTALLER v1.0" -ForegroundColor Cyan
Write-Host "    Ollama + Open WebUI + Qwen 3.5 9B" -ForegroundColor Cyan
Write-Host "  ============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "Installer started. ProjectRoot=$ProjectRoot" "INFO"

# ============================================================
# STEP 1: OS Check
# ============================================================
Write-Log "Checking operating system..." "STEP"
$os = [System.Environment]::OSVersion
Write-Log "OS: $($os.VersionString)" "INFO"
if ($os.Platform -ne "Win32NT") {
    Write-Log "This installer is for Windows only." "ERROR"
    exit 1
}
Write-Log "Windows detected." "OK"

# ============================================================
# STEP 2: RAM Check
# ============================================================
Write-Log "Checking system RAM..." "STEP"
$ram = (Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory
$ramGB = [math]::Round($ram / 1GB, 1)
Write-Log "Total RAM: ${ramGB} GB" "INFO"
if ($ramGB -lt 12) {
    Write-Log "Low RAM detected (${ramGB} GB). Minimum recommended is 12 GB. Proceeding with caution." "WARN"
} else {
    Write-Log "RAM is sufficient (${ramGB} GB)." "OK"
}

# ============================================================
# STEP 3: Disk Space Check
# ============================================================
Write-Log "Checking available disk space..." "STEP"
$drive = Split-Path -Qualifier $ProjectRoot
$disk  = Get-PSDrive ($drive.TrimEnd(':'))
$freeGB = [math]::Round($disk.Free / 1GB, 1)
Write-Log "Free space on ${drive}: ${freeGB} GB" "INFO"
if ($freeGB -lt 20) {
    Write-Log "Low disk space (${freeGB} GB free). Recommended: at least 20 GB free for models." "WARN"
    $continue = Read-Host "  Continue anyway? [y/N]"
    if ($continue -notmatch '^[Yy]') { Write-Log "User cancelled due to low disk space." "INFO"; exit 0 }
} else {
    Write-Log "Disk space is sufficient (${freeGB} GB free)." "OK"
}

# ============================================================
# STEP 4: NVIDIA GPU Check
# ============================================================
Write-Log "Checking for NVIDIA GPU..." "STEP"
$nvidiaSmi = $null
try {
    $nvidiaSmi = & nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>$null
} catch {}
if ($nvidiaSmi) {
    Write-Log "NVIDIA GPU found: $($nvidiaSmi.Trim())" "OK"
} else {
    Write-Log "NVIDIA GPU not detected. Ollama will run on CPU only (much slower)." "WARN"
    Write-Log "Make sure your NVIDIA drivers are installed. Visit: https://www.nvidia.com/drivers" "WARN"
    $continue = Read-Host "  Continue with CPU-only mode? [y/N]"
    if ($continue -notmatch '^[Yy]') { exit 0 }
}

# ============================================================
# STEP 5: Check / Install Ollama
# ============================================================
Write-Log "Checking for Ollama installation..." "STEP"
$ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue

if (-not $ollamaCmd) {
    Write-Log "Ollama not found. Downloading installer..." "INFO"
    $ollamaInstaller = Join-Path $env:TEMP "OllamaSetup.exe"
    try {
        Write-Host "  Downloading Ollama from ollama.com..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" `
            -OutFile $ollamaInstaller -UseBasicParsing
        Write-Log "Download complete. Running Ollama installer silently..." "INFO"
        Start-Process -FilePath $ollamaInstaller -ArgumentList "/S" -Wait
        Write-Log "Ollama installer finished." "INFO"

        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("Path","User")
        $ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
    } catch {
        Write-Log "Failed to download or install Ollama: $_" "ERROR"
        Write-Log "Please install Ollama manually from: https://ollama.com/download" "ERROR"
        exit 1
    }
}

if ($ollamaCmd) {
    $ollamaVersion = & ollama --version 2>&1
    Write-Log "Ollama is installed: $ollamaVersion" "OK"
} else {
    Write-Log "Ollama still not found after install attempt. Please install manually from https://ollama.com/download and re-run." "ERROR"
    exit 1
}

# ============================================================
# STEP 6: Check Docker Desktop
# ============================================================
Write-Log "Checking for Docker Desktop..." "STEP"
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue

if (-not $dockerCmd) {
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Yellow
    Write-Host "  Docker Desktop is NOT installed." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Docker Desktop is required to run the Open WebUI interface." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Please install it now:" -ForegroundColor Yellow
    Write-Host "  1. Go to: https://www.docker.com/products/docker-desktop/" -ForegroundColor White
    Write-Host "  2. Download and install Docker Desktop for Windows" -ForegroundColor White
    Write-Host "  3. Start Docker Desktop and wait for the whale icon in the tray" -ForegroundColor White
    Write-Host "  4. Press ENTER here to continue installation" -ForegroundColor White
    Write-Host "  ============================================================" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Press ENTER after Docker Desktop is installed and running"

    # Re-check
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $dockerCmd) {
        Write-Log "Docker still not found. Please install Docker Desktop and re-run install.bat." "ERROR"
        exit 1
    }
}

$dockerVersion = & docker --version 2>&1
Write-Log "Docker found: $dockerVersion" "OK"

# ============================================================
# STEP 7: Start Ollama Service
# ============================================================
Write-Log "Starting Ollama service..." "STEP"
$ollamaRunning = $false
try {
    $testResp = Invoke-WebRequest -Uri "http://localhost:11434" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    $ollamaRunning = ($testResp.StatusCode -lt 500)
} catch {}

if (-not $ollamaRunning) {
    Write-Log "Launching Ollama in background..." "INFO"
    Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden
    $ollamaRunning = Wait-ForPort -Url "http://localhost:11434" -TimeoutSeconds 30 -ServiceName "Ollama"
    if (-not $ollamaRunning) {
        Write-Log "Ollama failed to start. Check that it is installed correctly." "ERROR"
        exit 1
    }
} else {
    Write-Log "Ollama is already running." "OK"
}

# ============================================================
# STEP 8: Pull Models
# ============================================================
Write-Log "Pulling primary model: qwen3.5:9b (this may take 10-20 minutes on first run)..." "STEP"
Write-Host "  Downloading qwen3.5:9b model (~5 GB)..." -ForegroundColor Cyan
Write-Host "  This is a one-time download. Please be patient." -ForegroundColor DarkGray
& ollama pull qwen3.5:9b
if ($LASTEXITCODE -ne 0) {
    Write-Log "Failed to pull qwen3.5:9b. Check your internet connection." "ERROR"
    exit 1
}
Write-Log "qwen3.5:9b model ready." "OK"

Write-Log "Pulling backup model: qwen3.5:4b..." "STEP"
Write-Host "  Downloading qwen3.5:4b model (~2 GB)..." -ForegroundColor Cyan
& ollama pull qwen3.5:4b
if ($LASTEXITCODE -ne 0) {
    Write-Log "Failed to pull qwen3.5:4b. This is not critical - continuing." "WARN"
} else {
    Write-Log "qwen3.5:4b backup model ready." "OK"
}

# ============================================================
# STEP 9: Create Ollama Modelfiles for Profiles
# ============================================================
Write-Log "Creating model profiles (Modelfiles)..." "STEP"

$profiles = @(
    @{ Name = "qwen3.5:9b-maxperf";  Base = "qwen3.5:9b"; NumCtx = 4096; NumGpu = 36; NumThread = 10; Flash = 1 },
    @{ Name = "qwen3.5:9b-balanced"; Base = "qwen3.5:9b"; NumCtx = 2048; NumGpu = 36; NumThread = 8;  Flash = 1 },
    @{ Name = "qwen3.5:9b-safe";     Base = "qwen3.5:9b"; NumCtx = 1024; NumGpu = 20; NumThread = 4;  Flash = 0 },
    @{ Name = "qwen3.5:4b-fast";     Base = "qwen3.5:4b"; NumCtx = 4096; NumGpu = 36; NumThread = 10; Flash = 1 }
)

foreach ($p in $profiles) {
    $modelfileContent  = "FROM $($p.Base)`n"
    $modelfileContent += "PARAMETER num_ctx $($p.NumCtx)`n"
    $modelfileContent += "PARAMETER num_gpu $($p.NumGpu)`n"
    $modelfileContent += "PARAMETER num_thread $($p.NumThread)"
    if ($p.Flash -eq 1) { $modelfileContent += "`nPARAMETER use_mmap true" }

    $mfPath = Join-Path $env:TEMP "Modelfile_$($p.Name -replace '[:.]','-')"
    Set-Content -Path $mfPath -Value $modelfileContent -Encoding UTF8
    Write-Log "Creating Ollama model: $($p.Name)" "INFO"
    & ollama create $p.Name -f $mfPath 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Log "  Created: $($p.Name)" "OK"
    } else {
        Write-Log "  Warning: could not create $($p.Name) (non-critical)" "WARN"
    }
    Remove-Item $mfPath -Force -ErrorAction SilentlyContinue
}

# ============================================================
# STEP 10: Ensure Docker daemon is running
# ============================================================
Write-Log "Checking Docker daemon..." "STEP"
$dockerRunning = $false
try {
    $dockerInfo = & docker info 2>&1
    $dockerRunning = ($LASTEXITCODE -eq 0)
} catch {}

if (-not $dockerRunning) {
    Write-Log "Docker daemon not running. Attempting to start Docker Desktop..." "INFO"
    $dockerDesktopPaths = @(
        "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "$env:LOCALAPPDATA\Programs\Docker\Docker\Docker Desktop.exe"
    )
    $dockerExe = $null
    foreach ($p in $dockerDesktopPaths) {
        if (Test-Path $p) { $dockerExe = $p; break }
    }
    if ($dockerExe) {
        Start-Process $dockerExe
        Write-Log "Docker Desktop started. Waiting up to 60 seconds..." "INFO"
        $waited = 0
        while ($waited -lt 60) {
            Start-Sleep -Seconds 5
            $waited += 5
            $info = & docker info 2>&1
            if ($LASTEXITCODE -eq 0) { $dockerRunning = $true; break }
            Write-Host "    ...waiting for Docker daemon... ${waited}s / 60s" -ForegroundColor DarkGray
        }
    }
    if (-not $dockerRunning) {
        Write-Log "Docker daemon is not running. Please start Docker Desktop manually and re-run the installer." "ERROR"
        exit 1
    }
}
Write-Log "Docker daemon is running." "OK"

# ============================================================
# STEP 11: Start Open WebUI Container
# ============================================================
Write-Log "Setting up Open WebUI Docker container..." "STEP"

# Read port from settings.json (simple parse)
$webuiPort = 3000
try {
    $settings = Get-Content (Join-Path $ConfigDir "settings.json") | ConvertFrom-Json
    $webuiPort = $settings.webui_port
} catch {}

$containerName = "open-webui"
$existingContainer = & docker ps -a --filter "name=^${containerName}$" --format "{{.Names}}" 2>&1

if ($existingContainer -eq $containerName) {
    # Check if existing container has wrong port binding (0.0.0.0 instead of 127.0.0.1)
    $hostIpLine = & docker inspect $containerName 2>&1 | Select-String "HostIp"
    if ($hostIpLine -match '"0\.0\.0\.0"') {
        Write-Log "Existing container bound to 0.0.0.0 - recreating with 127.0.0.1 for security..." "WARN"
        & docker stop $containerName 2>&1 | Out-Null
        & docker rm $containerName 2>&1 | Out-Null
        # Fall through to creation block below
        $existingContainer = ""
    } else {
        Write-Log "open-webui container already exists. Starting it..." "INFO"
        & docker start $containerName 2>&1 | Out-Null
        Write-Log "Container started." "OK"
    }
}
if ($existingContainer -ne $containerName) {
    Write-Log "Creating open-webui container..." "INFO"
    & docker run -d `
        -p "127.0.0.1:${webuiPort}:8080" `
        --add-host=host.docker.internal:host-gateway `
        -e OLLAMA_BASE_URL=http://host.docker.internal:11434 `
        -e WEBUI_AUTH=False `
        -v open-webui:/app/backend/data `
        --name $containerName `
        --restart unless-stopped `
        ghcr.io/open-webui/open-webui:main 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to create Open WebUI container." "ERROR"
        Write-Log "Try running manually: docker run -d -p 127.0.0.1:3000:8080 --add-host=host.docker.internal:host-gateway -e OLLAMA_BASE_URL=http://host.docker.internal:11434 -e WEBUI_AUTH=False -v open-webui:/app/backend/data --name open-webui --restart unless-stopped ghcr.io/open-webui/open-webui:main" "ERROR"
        exit 1
    }
    Write-Log "open-webui container created." "OK"
}

# ============================================================
# STEP 12: Wait for WebUI to be ready
# ============================================================
Write-Log "Waiting for Open WebUI to be ready (first start may take 30-60 seconds)..." "STEP"
$webuiReady = Wait-ForPort -Url "http://localhost:${webuiPort}" -TimeoutSeconds 120 -ServiceName "Open WebUI"
if (-not $webuiReady) {
    Write-Log "Open WebUI did not start in time. It may still be loading. Try http://localhost:${webuiPort} in a minute." "WARN"
}

# ============================================================
# STEP 13: Create config\.env from example (if not exists)
# ============================================================
Write-Log "Setting up configuration file..." "STEP"
$envFile    = Join-Path $ConfigDir ".env"
$envExample = Join-Path $ConfigDir ".env.example"
if (-not (Test-Path $envFile)) {
    Copy-Item $envExample $envFile
    Write-Log "Created config\.env from example." "OK"
} else {
    Write-Log "config\.env already exists, skipping." "INFO"
}

# ============================================================
# STEP 14: Create Desktop Shortcut
# ============================================================
Write-Log "Creating desktop shortcut..." "STEP"
$shortcutScript = Join-Path $ProjectRoot "_engine\scripts\create-shortcut.ps1"
if (Test-Path $shortcutScript) {
    & powershell -ExecutionPolicy Bypass -File $shortcutScript -ProjectRoot $ProjectRoot
    Write-Log "Desktop shortcut created." "OK"
} else {
    Write-Log "create-shortcut.ps1 not found, skipping shortcut creation." "WARN"
}

# ============================================================
# STEP 15: Final Summary
# ============================================================
Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host "   INSTALLATION COMPLETE!" -ForegroundColor Green
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "   Models installed:" -ForegroundColor White
Write-Host "     - qwen3.5:9b  (primary, ~6.6 GB)" -ForegroundColor Gray
Write-Host "     - qwen3.5:4b  (backup,  ~2.5 GB)" -ForegroundColor Gray
Write-Host ""
Write-Host "   Web UI is running at:" -ForegroundColor White
Write-Host "     http://localhost:${webuiPort}" -ForegroundColor Cyan
Write-Host ""
Write-Host "   HOW TO USE:" -ForegroundColor White
Write-Host "     Daily use:  Double-click 'NeuralBox' on your desktop" -ForegroundColor Gray
Write-Host "             OR  Double-click start.bat" -ForegroundColor Gray
Write-Host ""
Write-Host "   PROFILE (performance):  config\.env  -> PROFILE=max-performance" -ForegroundColor Gray
Write-Host "   LOGS:                   logs\install.log" -ForegroundColor Gray
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host ""

Write-Log "Installation completed successfully." "OK"

# ============================================================
# STEP 16: Write installed flag so start.bat knows setup is done
# ============================================================
$flagFile = Join-Path $ConfigDir ".installed"
Set-Content -Path $flagFile -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Encoding UTF8
Write-Log "Wrote installed flag: $flagFile" "INFO"

# ============================================================
# STEP 17: Auto-launch after install
# ============================================================
Write-Host ""
Write-Host "  Launching Local AI now..." -ForegroundColor Cyan
Write-Host ""
Start-Sleep -Seconds 2
$launchScript = Join-Path $ProjectRoot "_engine\launcher\launch-ai.bat"
if (Test-Path $launchScript) {
    Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", $launchScript)
}
