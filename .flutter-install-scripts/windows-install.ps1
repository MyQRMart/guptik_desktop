# GupTik Desktop - Windows Installation Script (PowerShell)

Set-StrictMode -Version 2
$ErrorActionPreference = "Stop"

Write-Host "=== GupTik Desktop - Windows Installation ===" -ForegroundColor Green
Write-Host ""

# Check if running from project root
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "Error: pubspec.yaml not found. Please run this script from the project root." -ForegroundColor Red
    exit 1
}

# Build the Flutter Windows app
Write-Host "Building Flutter Windows application (Release mode)..."
& flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Build failed" -ForegroundColor Red
    exit 1
}

# Define installation paths
$InstallDir = "$env:LOCALAPPDATA\GupTik"
$BuildPath = "build\windows\x64\runner\Release"

# Check if build was successful
if (-not (Test-Path $BuildPath)) {
    Write-Host "Error: Build directory not found at $BuildPath" -ForegroundColor Red
    exit 1
}

Write-Host "Creating installation directory..."
if (Test-Path $InstallDir) {
    Remove-Item -Path $InstallDir -Recurse -Force
}
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

Write-Host "Copying application files..."
Copy-Item -Path "$BuildPath\*" -Destination $InstallDir -Recurse -Force

# Copy icon for shortcuts
$IconSource = "lib\assets\logonobg.png"
if (Test-Path $IconSource) {
    Copy-Item -Path $IconSource -Destination "$InstallDir\icon.png" -Force
}

# Create Start Menu shortcut
$StartMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
$ShortcutPath = "$StartMenuPath\GupTik Desktop.lnk"

Write-Host "Creating Start Menu shortcut..."
New-Item -ItemType Directory -Path $StartMenuPath -Force | Out-Null

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = "$InstallDir\guptik_desktop.exe"
$Shortcut.WorkingDirectory = $InstallDir
$Shortcut.IconLocation = "$InstallDir\guptik_desktop.exe"
$Shortcut.Description = "Guptik Desktop - Secure Vault Application"
$Shortcut.Save()

# Create Desktop shortcut
Write-Host "Creating Desktop shortcut..."
$DesktopPath = "$env:USERPROFILE\Desktop\GupTik Desktop.lnk"
$Shortcut2 = $WshShell.CreateShortcut($DesktopPath)
$Shortcut2.TargetPath = "$InstallDir\guptik_desktop.exe"
$Shortcut2.WorkingDirectory = $InstallDir
$Shortcut2.IconLocation = "$InstallDir\guptik_desktop.exe"
$Shortcut2.Description = "Guptik Desktop - Secure Vault Application"
$Shortcut2.Save()

Write-Host ""
Write-Host "=== Windows Installation Complete ===" -ForegroundColor Green
Write-Host "Installation location: $InstallDir"
Write-Host "Shortcuts created:"
Write-Host "  - Start Menu"
Write-Host "  - Desktop"
Write-Host ""
Write-Host "You can now launch GupTik Desktop from your Start Menu or Desktop shortcut"
