#!/bin/bash
# GupTik Desktop - Total Local Data Wipe (Linux)

INSTALL_DIR="$HOME/.local/share/guptik"
DESKTOP_DIR="$HOME/.local/share/applications"
LOCAL_BIN="$HOME/.local/bin"

# These are the specific folders where session data and preferences live
CONFIG_DIR="$HOME/.config/guptik_desktop" 
DATA_DIR="$HOME/.local/share/guptik_desktop"

echo "Stopping guptik_desktop processes..."
pkill -f guptik_desktop || true

echo "Removing binary and desktop entries..."
rm -rf "$INSTALL_DIR"
rm -f "$DESKTOP_DIR/com.stoneage.guptik_desktop.desktop"
rm -f "$LOCAL_BIN/guptik_desktop"

echo "Wiping persistent local preferences..."
# Deleting these ensures the QR Login appears on next install
rm -rf "$CONFIG_DIR"
rm -rf "$DATA_DIR"

if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

echo "✅ Linux Uninstallation Complete. All session data wiped."