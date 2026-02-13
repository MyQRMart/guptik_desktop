#!/bin/bash
# GupTik Desktop - Total Local Data Wipe (macOS)

MAC_BUNDLE_ID="com.example.guptikDesktop"

echo "Removing application bundle..."
rm -rf /Applications/guptik_desktop.app
rm -f /usr/local/bin/guptik_desktop

echo "Wiping macOS preferences, containers, and saved state..."
# macOS Flutter apps store shared_preferences in Containers or Application Support
rm -rf ~/Library/Containers/$MAC_BUNDLE_ID
rm -rf ~/Library/Application\ Support/$MAC_BUNDLE_ID
rm -rf ~/Library/Preferences/$MAC_BUNDLE_ID.plist
rm -rf ~/Library/Saved\ Application\ State/$MAC_BUNDLE_ID.savedState

# Wiping fallbacks just in case
rm -rf ~/Library/Application\ Support/guptik_desktop

echo "✅ macOS Uninstallation Complete. Login required on next launch."