# ============================================================
# create-shortcut.ps1
# Creates NeuralBox desktop shortcut with premium purple/gold icon
# ============================================================

param(
    [string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent)
)

$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$assetsDir   = Join-Path $ProjectRoot "assets"
$iconPath    = Join-Path $assetsDir "neuralbox.ico"
$launcherPath = Join-Path $ProjectRoot "start.bat"
$desktopPath  = [Environment]::GetFolderPath('Desktop')
$shortcutFile = Join-Path $desktopPath "NeuralBox.lnk"

# ── Create assets dir ──────────────────────────────────────────────────────
if (-not (Test-Path $assetsDir)) {
    New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
}

# ── Generate premium purple/gold "N" icon using System.Drawing ─────────────
try {
    Add-Type -AssemblyName System.Drawing

    $size = 256
    $bmp  = New-Object System.Drawing.Bitmap($size, $size)
    $g    = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode   = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    # --- Purple → Gold diagonal gradient background ---
    $gradBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        [System.Drawing.Point]::new(0, 0),
        [System.Drawing.Point]::new($size, $size),
        [System.Drawing.Color]::FromArgb(255, 90, 20, 200),   # deep purple
        [System.Drawing.Color]::FromArgb(255, 245, 158, 11)   # gold
    )

    # --- Rounded-rectangle clip path ---
    $radius = 52
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $gp.AddArc(0,              0,              $radius*2, $radius*2, 180, 90)
    $gp.AddArc($size-$radius*2, 0,             $radius*2, $radius*2, 270, 90)
    $gp.AddArc($size-$radius*2, $size-$radius*2, $radius*2, $radius*2, 0,   90)
    $gp.AddArc(0,              $size-$radius*2, $radius*2, $radius*2, 90,  90)
    $gp.CloseFigure()
    $g.SetClip($gp)
    $g.FillPath($gradBrush, $gp)

    # --- Subtle inner glow overlay (semi-transparent white radial) ---
    $glowBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($gp)
    $glowBrush.CenterPoint = [System.Drawing.PointF]::new(80, 70)
    $glowBrush.CenterColor = [System.Drawing.Color]::FromArgb(60, 255, 255, 255)
    $glowBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    $g.FillPath($glowBrush, $gp)

    # --- Bold white "N" centered ---
    $font = New-Object System.Drawing.Font("Arial", 148, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $sf   = New-Object System.Drawing.StringFormat
    $sf.Alignment     = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $rect = [System.Drawing.RectangleF]::new(0, 0, $size, $size)

    # Shadow behind N
    $shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(80, 0, 0, 0))
    $shadowRect  = [System.Drawing.RectangleF]::new(4, 6, $size, $size)
    $g.DrawString("N", $font, $shadowBrush, $shadowRect, $sf)

    # White N
    $g.DrawString("N", $font, [System.Drawing.Brushes]::White, $rect, $sf)

    $g.Dispose()

    # --- Save PNG then convert to ICO ---
    $pngPath = $iconPath -replace '\.ico$', '.png'
    $bmp.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()

    # Convert PNG to ICO (16, 32, 48, 256 px frames)
    function ConvertTo-Ico {
        param([string]$PngPath, [string]$IcoPath)
        $sizes = @(16, 32, 48, 256)
        $icoBytes = New-Object System.Collections.Generic.List[byte[]]

        foreach ($s in $sizes) {
            $img  = [System.Drawing.Image]::FromFile($PngPath)
            $thumb = New-Object System.Drawing.Bitmap($s, $s)
            $tg   = [System.Drawing.Graphics]::FromImage($thumb)
            $tg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $tg.DrawImage($img, 0, 0, $s, $s)
            $tg.Dispose(); $img.Dispose()
            $ms = New-Object System.IO.MemoryStream
            $thumb.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
            $thumb.Dispose()
            $icoBytes.Add($ms.ToArray())
            $ms.Dispose()
        }

        # ICO header
        $count = $sizes.Count
        $headerSize = 6 + $count * 16
        $offset = $headerSize
        $fs = [System.IO.File]::Open($IcoPath, [System.IO.FileMode]::Create)
        $bw = New-Object System.IO.BinaryWriter($fs)

        # ICONDIR
        $bw.Write([uint16]0)      # reserved
        $bw.Write([uint16]1)      # type = ICO
        $bw.Write([uint16]$count)

        foreach ($i in 0..($count-1)) {
            $s   = $sizes[$i]
            $data = $icoBytes[$i]
            $w   = if ($s -eq 256) { 0 } else { [byte]$s }
            $h   = if ($s -eq 256) { 0 } else { [byte]$s }
            $bw.Write([byte]$w)
            $bw.Write([byte]$h)
            $bw.Write([byte]0)     # color count
            $bw.Write([byte]0)     # reserved
            $bw.Write([uint16]1)   # planes
            $bw.Write([uint16]32)  # bit count
            $bw.Write([uint32]$data.Length)
            $bw.Write([uint32]$offset)
            $offset += $data.Length
        }

        foreach ($data in $icoBytes) { $bw.Write($data) }
        $bw.Dispose(); $fs.Dispose()
    }

    ConvertTo-Ico -PngPath $pngPath -IcoPath $iconPath
    Remove-Item $pngPath -Force -ErrorAction SilentlyContinue
    Write-Host "  [OK] NeuralBox icon created: $iconPath" -ForegroundColor Green

} catch {
    Write-Host "  [WARN] Could not generate icon: $_" -ForegroundColor Yellow
    $iconPath = "$env:SystemRoot\System32\shell32.dll,23"
}

# ── Create desktop shortcut ────────────────────────────────────────────────
try {
    $shell = New-Object -ComObject WScript.Shell
    $lnk   = $shell.CreateShortcut($shortcutFile)
    $lnk.TargetPath       = $launcherPath
    $lnk.WorkingDirectory = $ProjectRoot
    $lnk.IconLocation     = $iconPath
    $lnk.Description      = "NeuralBox - Your Private AI Empire"
    $lnk.WindowStyle      = 1
    $lnk.Save()
    Write-Host "  [OK] Desktop shortcut created: $shortcutFile" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  NeuralBox shortcut is on your Desktop!" -ForegroundColor Magenta
    Write-Host "  Double-click it to launch Your Private AI Empire." -ForegroundColor Magenta
} catch {
    Write-Host "  [ERROR] Could not create shortcut: $_" -ForegroundColor Red
    exit 1
}
