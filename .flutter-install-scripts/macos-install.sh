#!/bin/bash

# GupTik Desktop - macOS Installation Script

set -e

echo "Building Flutter macOS application (Release mode)..."
flutter build macos --release

echo ""
echo "Build complete. Installing application to Applications folder..."

# Build output path
BUILD_PATH="build/macos/Build/Products/Release/guptik_desktop.app"

if [ ! -d "$BUILD_PATH" ]; then
    echo "Error: Build directory not found at $BUILD_PATH"
    echo "Make sure build succeeded."
    exit 1
fi

# Remove existing installation if present
if [ -d "/Applications/guptik_desktop.app" ]; then
    echo "Removing existing installation..."
    rm -rf "/Applications/guptik_desktop.app"
fi

# Copy to Applications folder
echo "Copying application to /Applications..."
cp -r "$BUILD_PATH" "/Applications/guptik_desktop.app" || {
    echo "Error: Failed to copy app. You may need to run with sudo."
    echo "Try: sudo bash install.sh"
    exit 1
}

# Make it executable
chmod +x "/Applications/guptik_desktop.app/Contents/MacOS/guptik_desktop"

# Create symlink in /usr/local/bin for terminal access
echo "Creating terminal launcher..."
mkdir -p /usr/local/bin
cat > /tmp/guptik_desktop_launcher << 'SCRIPT'
#!/bin/bash
open /Applications/guptik_desktop.app
SCRIPT
chmod +x /tmp/guptik_desktop_launcher
sudo cp /tmp/guptik_desktop_launcher /usr/local/bin/guptik_desktop 2>/dev/null || {
    echo "Note: Could not create terminal launcher (requires sudo). You can launch from Applications folder."
}

echo ""
echo "=== macOS Installation Complete ==="
echo "The app is now in /Applications/guptik_desktop.app"
echo "Launch with: guptik_desktop (from terminal) or find it in Applications folder"
