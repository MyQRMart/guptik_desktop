# GupTik Desktop - Total Local Data Wipe (Windows)

# Target all possible AppData combinations for Flutter on Windows
$PathsToWipe = @(
    "$env:LOCALAPPDATA\GupTik",
    "$env:APPDATA\guptik_desktop",
    "$env:LOCALAPPDATA\guptik_desktop",
    "$env:APPDATA\com.example\guptik_desktop",
    "$env:LOCALAPPDATA\com.example\guptik_desktop",
    "$env:APPDATA\stoneage\guptik_desktop",
    "$env:LOCALAPPDATA\stoneage\guptik_desktop"
)

Write-Host "Stopping guptik_desktop..."
Stop-Process -Name "guptik_desktop" -ErrorAction SilentlyContinue

Write-Host "Removing application files and session data..."
foreach ($Path in $PathsToWipe) {
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force
    }
}

Write-Host "Removing shortcuts..."
Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\GupTik Desktop.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:USERPROFILE\Desktop\GupTik Desktop.lnk" -Force -ErrorAction SilentlyContinue

Write-Host "✅ Windows Uninstallation Complete. Session reset." -ForegroundColor Green