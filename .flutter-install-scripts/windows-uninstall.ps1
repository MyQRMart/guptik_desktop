# GupTik Desktop - Total Local Data Wipe (Windows)
$InstallDir = "$env:LOCALAPPDATA\GupTik"
$StartMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\GupTik Desktop.lnk"
$DesktopPath = "$env:USERPROFILE\Desktop\GupTik Desktop.lnk"

# Specific Flutter preference locations
$AppDataDir = "$env:APPDATA\guptik_desktop"
$LocalAppDataDir = "$env:LOCALAPPDATA\guptik_desktop"

Write-Host "Stopping guptik_desktop..."
Stop-Process -Name "guptik_desktop" -ErrorAction SilentlyContinue

Write-Host "Removing application files and shortcuts..."
if (Test-Path $InstallDir) { Remove-Item -Path $InstallDir -Recurse -Force }
Remove-Item -Path $StartMenuPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path $DesktopPath -Force -ErrorAction SilentlyContinue

Write-Host "Wiping persistent AppData (Login state)..."
if (Test-Path $AppDataDir) { Remove-Item -Path $AppDataDir -Recurse -Force }
if (Test-Path $LocalAppDataDir) { Remove-Item -Path $LocalAppDataDir -Recurse -Force }

Write-Host "✅ Windows Uninstallation Complete. Session reset." -ForegroundColor Green