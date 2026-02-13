#!/bin/bash
# GupTik Desktop - Total Local Data Wipe (Linux)

APP_ID="com.stoneage.guptik_desktop"

echo "Stopping guptik_desktop processes..."
pkill -f guptik_desktop || true

echo "Removing binary and desktop entries..."
rm -rf "$HOME/.local/share/guptik"
rm -f "$HOME/.local/share/applications/$APP_ID.desktop"
rm -f "$HOME/.local/bin/guptik_desktop"

echo "Wiping Flutter shared_preferences and local databases..."
# Flutter Linux specifically uses the application ID for storage
rm -rf "$HOME/.local/share/$APP_ID"
rm -rf "$HOME/.config/$APP_ID"

# Wiping fallbacks just in case
rm -rf "$HOME/.local/share/guptik_desktop"
rm -rf "$HOME/.config/guptik_desktop"

if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

echo "✅ Linux Uninstallation Complete. All session data wiped."