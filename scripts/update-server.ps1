# ============================================================
# update-server.ps1
# A tiny HTTP server that listens on localhost:9999
# and lets Open WebUI trigger updates via API calls.
#
# Started automatically by launch-ai.bat
# Stopped automatically by stop-ai.bat
# ============================================================

param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [int]$Port = 9999
)

$LogFile    = Join-Path $ProjectRoot "logs\update-server.log"
$StatusFile = Join-Path $ProjectRoot "logs\update-status.json"
$LogicScript= Join-Path $ProjectRoot "scripts\update-logic.ps1"

function Write-Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$ts] $msg" | Add-Content -Path $LogFile -Encoding UTF8
}

function Set-StatusIdle {
    @{ status = "idle"; message = "Ready to update."; timestamp = "" } |
        ConvertTo-Json | Set-Content -Path $StatusFile -Encoding UTF8
}

function Send-Json($res, $obj, [int]$code = 200) {
    $json   = $obj | ConvertTo-Json -Compress
    $bytes  = [System.Text.Encoding]::UTF8.GetBytes($json)
    $res.StatusCode          = $code
    $res.ContentType         = "application/json; charset=utf-8"
    $res.ContentLength64     = $bytes.Length
    $res.Headers.Add("Access-Control-Allow-Origin",  "*")
    $res.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    $res.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
    $res.OutputStream.Close()
}

# ---- Init ---------------------------------------------------
if (-not (Test-Path (Split-Path $LogFile)))  { New-Item -ItemType Directory -Path (Split-Path $LogFile)  -Force | Out-Null }
if (-not (Test-Path (Split-Path $StatusFile))){ New-Item -ItemType Directory -Path (Split-Path $StatusFile) -Force | Out-Null }
Set-StatusIdle

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")

try {
    $listener.Start()
} catch {
    Write-Log "ERROR: Could not start listener on port $Port  -  $_"
    exit 1
}

Write-Log "Update server started on http://localhost:$Port"

# ---- Main loop ----------------------------------------------
while ($listener.IsListening) {
    try {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response
        $path = $req.Url.AbsolutePath

        Write-Log "$($req.HttpMethod) $path"

        # Handle CORS pre-flight
        if ($req.HttpMethod -eq "OPTIONS") {
            Send-Json $res @{ ok = $true }
            continue
        }

        switch ($path) {

            # -- Health check ---------------------------------
            "/api/health" {
                Send-Json $res @{
                    status  = "ok"
                    message = "Local AI Update Server is running"
                }
            }

            # -- Start update ---------------------------------
            "/api/update" {
                $current = Get-Content $StatusFile -Raw | ConvertFrom-Json
                if ($current.status -eq "running") {
                    Send-Json $res @{
                        status  = "already_running"
                        message = "Update is already in progress. Check /api/status."
                    }
                } else {
                    # Write running status immediately
                    @{
                        status    = "running"
                        message   = "Update started..."
                        timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                        steps     = @()
                    } | ConvertTo-Json | Set-Content $StatusFile -Encoding UTF8

                    # Run update logic in background job
                    $null = Start-Job -ScriptBlock {
                        param($script, $root, $sf)
                        powershell -ExecutionPolicy Bypass -WindowStyle Hidden `
                            -File $script -ProjectRoot $root -StatusFile $sf
                    } -ArgumentList $LogicScript, $ProjectRoot, $StatusFile

                    Send-Json $res @{
                        status  = "started"
                        message = "Update started in background. Poll /api/status for progress."
                    }
                }
            }

            # -- Status ---------------------------------------
            "/api/status" {
                if (Test-Path $StatusFile) {
                    $raw   = Get-Content $StatusFile -Raw -Encoding UTF8
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
                    $res.StatusCode      = 200
                    $res.ContentType     = "application/json; charset=utf-8"
                    $res.ContentLength64 = $bytes.Length
                    $res.Headers.Add("Access-Control-Allow-Origin", "*")
                    $res.OutputStream.Write($bytes, 0, $bytes.Length)
                    $res.OutputStream.Close()
                } else {
                    Send-Json $res @{ status = "idle"; message = "No update has run yet." }
                }
            }

            # -- Reset status (after reading complete/error) --
            "/api/reset" {
                Set-StatusIdle
                Send-Json $res @{ status = "ok"; message = "Status reset to idle." }
            }

            default {
                Send-Json $res @{ error = "Unknown endpoint: $path" } -code 404
            }
        }

    } catch [System.Net.HttpListenerException] {
        # Listener was stopped intentionally
        break
    } catch {
        Write-Log "Loop error: $_"
    }
}

Write-Log "Update server stopped."
