#!/bin/bash
# GupTik Desktop - Total Local Data Wipe (macOS)

echo "Removing application bundle..."
rm -rf /Applications/guptik_desktop.app
rm -f /usr/local/bin/guptik_desktop

echo "Wiping macOS preferences and saved state..."
# Specific macOS paths for Flutter app data
rm -rf ~/Library/Application\ Support/guptik_desktop
rm -rf ~/Library/Preferences/com.stoneage.guptik_desktop.plist
rm -rf ~/Library/Saved\ Application\ State/com.stoneage.guptik_desktop.savedState

echo "✅ macOS Uninstallation Complete. Login required on next launch."