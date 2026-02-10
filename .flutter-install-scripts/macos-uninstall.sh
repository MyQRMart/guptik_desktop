#!/bin/bash

# GupTik Desktop - macOS Uninstallation Script

echo "Removing GupTik Desktop from /Applications..."
rm -rf /Applications/guptik_desktop.app

echo "Removing terminal launcher..."
rm -f /usr/local/bin/guptik_desktop

echo ""
echo "=== macOS Uninstallation Complete ==="
