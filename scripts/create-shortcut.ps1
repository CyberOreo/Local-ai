# ============================================================
# create-shortcut.ps1
# Creates a "Local AI" desktop shortcut pointing to launch-ai.bat
# Can be called from install.ps1 or run manually.
# ============================================================

param(
    [string]$ProjectRoot = $PSScriptRoot + "\.."
)

$ProjectRoot = (Resolve-Path $ProjectRoot).Path

$launcherPath = Join-Path $ProjectRoot "launcher\launch-ai.bat"
$iconPath     = Join-Path $ProjectRoot "assets\icon.ico"
$shortcutDir  = Join-Path $ProjectRoot "shortcuts"
$desktopPath  = [Environment]::GetFolderPath('Desktop')

# Ensure shortcut folder exists
if (-not (Test-Path $shortcutDir)) {
    New-Item -ItemType Directory -Path $shortcutDir -Force | Out-Null
}

# Determine icon: use custom icon.ico if it exists, else default
$iconLocation = if (Test-Path $iconPath) { $iconPath } else { "$env:SystemRoot\System32\shell32.dll,23" }

# Create WScript Shell COM object
$WshShell = New-Object -ComObject WScript.Shell

foreach ($targetDir in @($desktopPath, $shortcutDir)) {
    $shortcutFile = Join-Path $targetDir "Local AI.lnk"
    $Shortcut = $WshShell.CreateShortcut($shortcutFile)
    $Shortcut.TargetPath       = $launcherPath
    $Shortcut.WorkingDirectory = Join-Path $ProjectRoot "launcher"
    $Shortcut.Description      = "Launch Local AI (Ollama + Open WebUI)"
    $Shortcut.IconLocation     = $iconLocation
    $Shortcut.Save()
    Write-Host "  [OK] Shortcut created: $shortcutFile" -ForegroundColor Green
}

Write-Host ""
Write-Host "  Desktop shortcut 'Local AI' is ready." -ForegroundColor Cyan
Write-Host "  Double-click it to start your local AI." -ForegroundColor Cyan
