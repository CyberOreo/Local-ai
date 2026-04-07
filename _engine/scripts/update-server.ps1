# ============================================================
# update-server.ps1
# A tiny HTTP server that listens on localhost:9999
# and lets the NeuralBox hub trigger updates via API calls.
#
# Started automatically by launch-ai.bat
# Stopped automatically by stop-ai.bat
# ============================================================

param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [int]$Port = 9999
)

$LogFile    = Join-Path $ProjectRoot "logs\update-server.log"
$StatusFile = Join-Path $ProjectRoot "logs\update-status.json"
$LogicScript= Join-Path $ProjectRoot "_engine\scripts\update-logic.ps1"

function Write-Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$ts] $msg" | Add-Content -Path $LogFile -Encoding UTF8
}

function Set-StatusIdle {
    @{ status = "idle"; message = "Ready to update."; timestamp = "" } |
        ConvertTo-Json | Set-Content -Path $StatusFile -Encoding UTF8
}

function Is-LocalOrigin($req) {
    $origin = $req.Headers["Origin"]
    $host   = $req.Headers["Host"]
    # Allow requests with no Origin (direct tool/script calls)
    if ([string]::IsNullOrEmpty($origin)) { return $true }
    # Allow only localhost origins
    if ($origin -match '^https?://(localhost|127\.0\.0\.1)(:\d+)?$') { return $true }
    return $false
}

function Send-Json($res, $obj, [int]$code = 200) {
    $json   = $obj | ConvertTo-Json -Compress
    $bytes  = [System.Text.Encoding]::UTF8.GetBytes($json)
    $res.StatusCode          = $code
    $res.ContentType         = "application/json; charset=utf-8"
    $res.ContentLength64     = $bytes.Length
    $res.Headers.Add("Access-Control-Allow-Origin",  "http://localhost:8080")
    $res.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    $res.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
    $res.OutputStream.Close()
}

function Send-Forbidden($res) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes('{"error":"forbidden"}')
    $res.StatusCode      = 403
    $res.ContentType     = "application/json; charset=utf-8"
    $res.ContentLength64 = $bytes.Length
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
    $res.OutputStream.Close()
}

# ---- Init ---------------------------------------------------
if (-not (Test-Path (Split-Path $LogFile)))   { New-Item -ItemType Directory -Path (Split-Path $LogFile)   -Force | Out-Null }
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
Write-Log "Logic script path: $LogicScript"

# ---- Main loop ----------------------------------------------
while ($listener.IsListening) {
    try {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response
        $path = $req.Url.AbsolutePath

        Write-Log "$($req.HttpMethod) $path from $($req.RemoteEndPoint)"

        # Handle CORS pre-flight
        if ($req.HttpMethod -eq "OPTIONS") {
            Send-Json $res @{ ok = $true }
            continue
        }

        switch ($path) {

            # -- Health check (read-only, no auth required) --------
            "/api/health" {
                Send-Json $res @{
                    status  = "ok"
                    message = "NeuralBox Update Server is running"
                }
            }

            # -- Status (read-only) --------------------------------
            "/api/status" {
                if (Test-Path $StatusFile) {
                    $raw   = Get-Content $StatusFile -Raw -Encoding UTF8
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
                    $res.StatusCode      = 200
                    $res.ContentType     = "application/json; charset=utf-8"
                    $res.ContentLength64 = $bytes.Length
                    $res.Headers.Add("Access-Control-Allow-Origin", "http://localhost:8080")
                    $res.OutputStream.Write($bytes, 0, $bytes.Length)
                    $res.OutputStream.Close()
                } else {
                    Send-Json $res @{ status = "idle"; message = "No update has run yet." }
                }
            }

            # -- Start update (write — validate origin) ------------
            "/api/update" {
                if (-not (Is-LocalOrigin $req)) {
                    Write-Log "BLOCKED: /api/update from non-local origin: $($req.Headers['Origin'])"
                    Send-Forbidden $res
                    continue
                }
                if ($req.HttpMethod -ne "POST") {
                    Send-Json $res @{ error = "POST required" } -code 405
                    continue
                }
                $current = Get-Content $StatusFile -Raw | ConvertFrom-Json
                if ($current.status -eq "running") {
                    Send-Json $res @{
                        status  = "already_running"
                        message = "Update is already in progress. Check /api/status."
                    }
                } else {
                    @{
                        status    = "running"
                        message   = "Update started..."
                        timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                        steps     = @()
                    } | ConvertTo-Json | Set-Content $StatusFile -Encoding UTF8

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

            # -- Reset status (write — validate origin) ------------
            "/api/reset" {
                if (-not (Is-LocalOrigin $req)) {
                    Write-Log "BLOCKED: /api/reset from non-local origin"
                    Send-Forbidden $res
                    continue
                }
                if ($req.HttpMethod -ne "POST") {
                    Send-Json $res @{ error = "POST required" } -code 405
                    continue
                }
                Set-StatusIdle
                Send-Json $res @{ status = "ok"; message = "Status reset to idle." }
            }

            default {
                Send-Json $res @{ error = "Unknown endpoint: $path" } -code 404
            }
        }

    } catch [System.Net.HttpListenerException] {
        break
    } catch {
        Write-Log "Loop error: $_"
    }
}

Write-Log "Update server stopped."
