#!/bin/bash

# GupTik Desktop - Linux Installation Script

set -e

echo "Building Flutter Linux application (Release mode)..."
flutter build linux --release

echo ""
echo "Build complete. Installing application..."

# Create installation directories
INSTALL_DIR="$HOME/.local/share/guptik"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
LOCAL_BIN="$HOME/.local/bin"

echo "Creating installation directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$DESKTOP_DIR"
mkdir -p "$ICON_DIR"
mkdir -p "$LOCAL_BIN"

echo "Copying application binary and resources..."
# Copy the built bundle
cp -r build/linux/x64/release/bundle/* "$INSTALL_DIR/" || {
    echo "Error: Build directory not found. Make sure build succeeded."
    exit 1
}

# Make the binary executable
chmod +x "$INSTALL_DIR/guptik_desktop"

# Copy icon
echo "Installing application icon..."
cp lib/assets/logonobg.png "$ICON_DIR/guptik_desktop.png"

# Create a wrapper script in ~/.local/bin for easy access
cat > "$LOCAL_BIN/guptik_desktop" << 'SCRIPT'
#!/bin/bash
# GupTik Desktop Launcher
# Ensure we run from the install directory so resources are found
cd "$HOME/.local/share/guptik" || exit 1
nohup ./guptik_desktop "$@" >/dev/null 2>&1 &
exit 0
SCRIPT
chmod +x "$LOCAL_BIN/guptik_desktop"

# Copy desktop file
echo "Installing desktop entry..."
cp linux/com.stoneage.guptik_desktop.desktop "$DESKTOP_DIR/com.stoneage.guptik_desktop.desktop"

# Update desktop database
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

# Update icon cache
if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache "$HOME/.local/share/icons/hicolor/" 2>/dev/null || true
fi

echo ""
echo "=== Linux Installation Complete ==="
echo "Application installed successfully!"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    echo "✓ ~/.local/bin is in your PATH"
else
    echo "⚠ Adding ~/.local/bin to PATH..."
    echo ""
    echo "Add this line to your ~/.bashrc or ~/.zshrc:"
    echo "  export PATH=\"\$PATH:\$HOME/.local/bin\""
    echo ""
    echo "Then reload with: source ~/.bashrc (or ~/.zshrc)"
fi

echo ""
echo "You can find it in your applications menu or launch with: guptik_desktop"
