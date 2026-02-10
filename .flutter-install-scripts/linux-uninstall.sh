#!/bin/bash

# GupTik Desktop - Linux Uninstallation Script

INSTALL_DIR="$HOME/.local/share/guptik"
DESKTOP_DIR="$HOME/.local/share/applications"
LOCAL_BIN="$HOME/.local/bin"

# Check if installed
if [ ! -d "$INSTALL_DIR" ]; then
    echo "Application does not appear to be installed."
    exit 1
fi

echo "Removing application files..."
rm -rf "$INSTALL_DIR"

echo "Removing desktop entry..."
rm -f "$DESKTOP_DIR/com.stoneage.guptik_desktop.desktop"

echo "Removing launcher script..."
rm -f "$LOCAL_BIN/guptik_desktop"

# Update desktop database
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

echo ""
echo "=== Linux Uninstallation Complete ==="
