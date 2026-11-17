param([switch]$Uninstall)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$PackageDirectory = $PSScriptRoot
$SkinName = "GTA6Countdown"
$DataDirectory = Join-Path $env:LOCALAPPDATA "GTA6Countdown"
$WallpaperFile = Join-Path $DataDirectory "wallpaper-with-logo.jpg"
$PreviousWallpaperFile = Join-Path $DataDirectory "previous-wallpaper.json"
$RockstarMediaUrl = "https://www.rockstargames.com/VI/_next/static/media"
$ArtworkUrl = "$RockstarMediaUrl/an-extended-look.0zw.9~1j0ne~4.jpg"
$LogoTitleUrl = "$RockstarMediaUrl/logo_gta.0h_86ilgw96eh.png"
$LogoNumeralUrl = "$RockstarMediaUrl/logo_vi.13u0vs8.9roug.png"
$FontArchiveUrl = "https://dl.dafont.com/dl/?f=pricedown"
$FontFileName = "Pricedown Bl.otf"
$LogoVisibleArea = @{ X = 327; Y = 532; Width = 1107; Height = 854 }
$LogoWidthPerScreenHeight = 310 / 1440
$LogoMarginPerScreenHeight = 40 / 1440
$FillWallpaperStyle = "10"

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class NativeDesktop {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int SystemParametersInfo(int action, int parameter, string value, int flags);
}
"@

function Stop-WithError([string]$Message) {
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Find-RainmeterExecutable {
    $candidates = @(
        (Join-Path $env:ProgramFiles "Rainmeter\Rainmeter.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Rainmeter\Rainmeter.exe")
    )
    return $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

function Get-RainmeterExecutable {
    $executable = Find-RainmeterExecutable
    if ($executable) { return $executable }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Stop-WithError "Rainmeter not found. Install it from https://www.rainmeter.net and run the script again."
    }
    Write-Host "Rainmeter not found, installing it with winget..."
    winget install --id Rainmeter.Rainmeter --exact --accept-source-agreements --accept-package-agreements | Out-Host
    $executable = Find-RainmeterExecutable
    if (-not $executable) { Stop-WithError "Rainmeter installation failed. Install it from https://www.rainmeter.net" }
    return $executable
}

function Get-SkinsDirectory {
    $settingsFile = Join-Path $env:APPDATA "Rainmeter\Rainmeter.ini"
    if (Test-Path $settingsFile) {
        $skinPathLine = Select-String -Path $settingsFile -Pattern "^SkinPath=(.+)$" | Select-Object -First 1
        if ($skinPathLine) { return $skinPathLine.Matches[0].Groups[1].Value.Trim() }
    }
    return Join-Path ([Environment]::GetFolderPath("MyDocuments")) "Rainmeter\Skins"
}

function Get-PrimaryScreenSize {
    [NativeDesktop]::SetProcessDPIAware() | Out-Null
    Add-Type -AssemblyName System.Windows.Forms
    return [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
}

function Save-Download([string]$Url, [string]$Destination) {
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -UserAgent "Mozilla/5.0"
    } catch {
        Stop-WithError "download failed: $Url (Rockstar may have changed its website)."
    }
}

function New-CombinedLogo([string]$WorkDirectory) {
    $numeral = [System.Drawing.Image]::FromFile((Join-Path $WorkDirectory "logo-numeral.png"))
    $title = [System.Drawing.Image]::FromFile((Join-Path $WorkDirectory "logo-title.png"))
    $logo = New-Object System.Drawing.Bitmap($numeral.Width, $numeral.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($logo)
    $fullArea = New-Object System.Drawing.Rectangle(0, 0, $numeral.Width, $numeral.Height)
    $graphics.DrawImage($numeral, $fullArea)
    $graphics.DrawImage($title, $fullArea)
    $graphics.Dispose()
    $numeral.Dispose()
    $title.Dispose()
    return $logo
}

function Save-Jpeg([System.Drawing.Bitmap]$Image, [string]$Destination) {
    $jpegEncoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
    $encoderParameters = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $encoderParameters.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]95)
    $Image.Save($Destination, $jpegEncoder, $encoderParameters)
}

function New-WallpaperWithLogo([string]$WorkDirectory, $ScreenSize) {
    Add-Type -AssemblyName System.Drawing
    $artwork = [System.Drawing.Image]::FromFile((Join-Path $WorkDirectory "artwork.jpg"))
    $logo = New-CombinedLogo $WorkDirectory
    $zoom = [Math]::Max($ScreenSize.Width / $artwork.Width, $ScreenSize.Height / $artwork.Height)
    $visibleWidth = $ScreenSize.Width / $zoom
    $visibleLeft = ($artwork.Width - $visibleWidth) / 2
    $visibleTop = ($artwork.Height - $ScreenSize.Height / $zoom) / 2
    $logoWidth = [int]($ScreenSize.Height * $LogoWidthPerScreenHeight / $zoom)
    $logoHeight = [int]($logoWidth * $LogoVisibleArea.Height / $LogoVisibleArea.Width)
    $margin = $ScreenSize.Height * $LogoMarginPerScreenHeight / $zoom
    $logoX = [int]($visibleLeft + $visibleWidth - $margin - $logoWidth)
    $logoY = [int]($visibleTop + $margin)

    $wallpaper = New-Object System.Drawing.Bitmap($artwork.Width, $artwork.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($wallpaper)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($artwork, (New-Object System.Drawing.Rectangle(0, 0, $artwork.Width, $artwork.Height)))
    $logoDestination = New-Object System.Drawing.Rectangle($logoX, $logoY, $logoWidth, $logoHeight)
    $logoSource = New-Object System.Drawing.Rectangle($LogoVisibleArea.X, $LogoVisibleArea.Y, $LogoVisibleArea.Width, $LogoVisibleArea.Height)
    $graphics.DrawImage($logo, $logoDestination, $logoSource, [System.Drawing.GraphicsUnit]::Pixel)
    $graphics.Dispose()
    Save-Jpeg $wallpaper $WallpaperFile
    $wallpaper.Dispose()
    $logo.Dispose()
    $artwork.Dispose()
}

function Set-DesktopWallpaper([string]$ImagePath, [string]$Style) {
    $desktopSettings = "HKCU:\Control Panel\Desktop"
    Set-ItemProperty -Path $desktopSettings -Name WallpaperStyle -Value $Style
    Set-ItemProperty -Path $desktopSettings -Name TileWallpaper -Value "0"
    [NativeDesktop]::SystemParametersInfo(20, 0, $ImagePath, 3) | Out-Null
}

function Save-PreviousWallpaper {
    if (Test-Path $PreviousWallpaperFile) { return }
    $desktopSettings = Get-ItemProperty -Path "HKCU:\Control Panel\Desktop"
    @{ Path = $desktopSettings.WallPaper; Style = $desktopSettings.WallpaperStyle } | ConvertTo-Json | Set-Content $PreviousWallpaperFile
}

function Install-Font([string]$WorkDirectory, [string]$SkinDirectory) {
    Write-Host "Downloading the Pricedown font (free, Typodermic Desktop license)..."
    $archive = Join-Path $WorkDirectory "pricedown.zip"
    Save-Download $FontArchiveUrl $archive
    Expand-Archive -Path $archive -DestinationPath (Join-Path $WorkDirectory "font") -Force
    $fontsDirectory = Join-Path $SkinDirectory "@Resources\Fonts"
    New-Item -ItemType Directory -Force -Path $fontsDirectory | Out-Null
    Copy-Item (Join-Path $WorkDirectory "font\$FontFileName") $fontsDirectory -Force
}

function Start-RainmeterIfNeeded([string]$RainmeterExecutable) {
    if (Get-Process -Name Rainmeter -ErrorAction SilentlyContinue) { return }
    Start-Process $RainmeterExecutable
    Start-Sleep -Seconds 5
}

function Install-Everything {
    $rainmeterExecutable = Get-RainmeterExecutable
    $screenSize = Get-PrimaryScreenSize
    Write-Host "Primary screen: $($screenSize.Width)x$($screenSize.Height)"
    New-Item -ItemType Directory -Force -Path $DataDirectory | Out-Null
    $workDirectory = Join-Path ([IO.Path]::GetTempPath()) ("gta6-countdown-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $workDirectory | Out-Null
    try {
        Write-Host "Downloading the official artwork and logo from the Rockstar website..."
        Save-Download $ArtworkUrl (Join-Path $workDirectory "artwork.jpg")
        Save-Download $LogoTitleUrl (Join-Path $workDirectory "logo-title.png")
        Save-Download $LogoNumeralUrl (Join-Path $workDirectory "logo-numeral.png")
        New-WallpaperWithLogo $workDirectory $screenSize

        Start-RainmeterIfNeeded $rainmeterExecutable
        & $rainmeterExecutable "!DeactivateConfig" $SkinName
        $skinDirectory = Join-Path (Get-SkinsDirectory) $SkinName
        if (Test-Path $skinDirectory) { Remove-Item $skinDirectory -Recurse -Force }
        Copy-Item (Join-Path $PackageDirectory "Skins\$SkinName") $skinDirectory -Recurse
        Install-Font $workDirectory $skinDirectory
    } finally {
        Remove-Item $workDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }

    Save-PreviousWallpaper
    Set-DesktopWallpaper $WallpaperFile $FillWallpaperStyle
    & $rainmeterExecutable "!RefreshApp"
    Start-Sleep -Seconds 3
    & $rainmeterExecutable "!ActivateConfig" $SkinName "Countdown.ini"
    Write-Host ""
    Write-Host "Done! Double-click the countdown to unlock it and drag it around." -ForegroundColor Green
    Write-Host "To remove everything: double-click uninstall.bat"
}

function Remove-Everything {
    $rainmeterExecutable = Find-RainmeterExecutable
    if ($rainmeterExecutable -and (Get-Process -Name Rainmeter -ErrorAction SilentlyContinue)) {
        & $rainmeterExecutable "!DeactivateConfig" $SkinName
        Start-Sleep -Seconds 2
    }
    $skinDirectory = Join-Path (Get-SkinsDirectory) $SkinName
    if (Test-Path $skinDirectory) { Remove-Item $skinDirectory -Recurse -Force }
    if (Test-Path $PreviousWallpaperFile) {
        $previousWallpaper = Get-Content $PreviousWallpaperFile -Raw | ConvertFrom-Json
        Set-DesktopWallpaper $previousWallpaper.Path $previousWallpaper.Style
    }
    if (Test-Path $DataDirectory) { Remove-Item $DataDirectory -Recurse -Force }
    Write-Host "Removed: countdown and wallpaper. Previous wallpaper restored." -ForegroundColor Green
    Write-Host "Rainmeter is still installed: if you do not need it, uninstall it from Settings > Apps."
}

if ($Uninstall) { Remove-Everything } else { Install-Everything }
