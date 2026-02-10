# GupTik Desktop - Windows Uninstallation Script (PowerShell)

Set-StrictMode -Version 2
$ErrorActionPreference = "Stop"

Write-Host "=== GupTik Desktop - Windows Uninstallation ===" -ForegroundColor Green
Write-Host ""

# Define paths
$InstallDir = "$env:LOCALAPPDATA\GupTik"
$StartMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\GupTik Desktop.lnk"
$DesktopPath = "$env:USERPROFILE\Desktop\GupTik Desktop.lnk"

# Check if installed
if (-not (Test-Path $InstallDir)) {
    Write-Host "Application does not appear to be installed." -ForegroundColor Yellow
    Write-Host "Installation directory not found: $InstallDir"
    exit 1
}

Write-Host "Removing application files..."
Remove-Item -Path $InstallDir -Recurse -Force

Write-Host "Removing shortcuts..."
Remove-Item -Path $StartMenuPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path $DesktopPath -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== Windows Uninstallation Complete ===" -ForegroundColor Green
Write-Host "The application has been removed from your system."
