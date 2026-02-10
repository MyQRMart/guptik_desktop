#!/bin/bash

# GupTik Desktop - Installation Verification Script

echo "=== GupTik Desktop Installation Verification ==="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

INSTALL_DIR="$HOME/.local/share/guptik"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
LOCAL_BIN="$HOME/.local/bin"

# Check installation directory
echo "Checking installation..."
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${GREEN}✓${NC} Installation directory found"
    if [ -f "$INSTALL_DIR/guptik_desktop" ]; then
        echo -e "${GREEN}✓${NC} Binary executable found"
        if [ -x "$INSTALL_DIR/guptik_desktop" ]; then
            echo -e "${GREEN}✓${NC} Binary is executable"
        else
            echo -e "${RED}✗${NC} Binary is not executable"
        fi
    else
        echo -e "${RED}✗${NC} Binary not found"
    fi
else
    echo -e "${RED}✗${NC} Installation directory not found: $INSTALL_DIR"
    echo "Run: bash install.sh"
    exit 1
fi

# Check desktop entry
echo ""
echo "Checking desktop entry..."
if [ -f "$DESKTOP_DIR/com.stoneage.guptik_desktop.desktop" ]; then
    echo -e "${GREEN}✓${NC} Desktop entry found"
else
    echo -e "${RED}✗${NC} Desktop entry not found"
fi

# Check launcher script
echo ""
echo "Checking launcher script..."
if [ -f "$LOCAL_BIN/guptik_desktop" ]; then
    echo -e "${GREEN}✓${NC} Launcher script found"
    if [ -x "$LOCAL_BIN/guptik_desktop" ]; then
        echo -e "${GREEN}✓${NC} Launcher is executable"
    else
        echo -e "${RED}✗${NC} Launcher is not executable"
    fi
else
    echo -e "${YELLOW}⚠${NC} Launcher script not found in $LOCAL_BIN/guptik_desktop"
fi

# Check icon
echo ""
echo "Checking icon..."
if [ -f "$ICON_DIR/guptik_desktop.png" ]; then
    echo -e "${GREEN}✓${NC} Icon found"
else
    echo -e "${YELLOW}⚠${NC} Icon not found (decorative only)"
fi

# Check PATH
echo ""
echo "Checking PATH configuration..."
if [[ ":$PATH:" == *":$LOCAL_BIN:"* ]]; then
    echo -e "${GREEN}✓${NC} ~/.local/bin is in PATH"
else
    echo -e "${RED}✗${NC} ~/.local/bin is NOT in PATH"
    echo "  Add this to ~/.bashrc or ~/.zshrc:"
    echo "  export PATH=\"\$PATH:\$HOME/.local/bin\""
    echo "  Then run: source ~/.bashrc"
fi

# Try to run the app
echo ""
echo "Testing application launch..."
if command -v guptik_desktop &> /dev/null; then
    echo -e "${GREEN}✓${NC} 'guptik_desktop' command is available"
    echo "  Running in background... (you should see the app window)"
    guptik_desktop &
    APP_PID=$!
    sleep 2
    if kill -0 $APP_PID 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Application is running (PID: $APP_PID)"
        echo "  Close the application manually"
    else
        echo -e "${RED}✗${NC} Application exited unexpectedly"
    fi
else
    echo -e "${RED}✗${NC} 'guptik_desktop' command not found"
    echo "  Try running it with full path:"
    echo "  $INSTALL_DIR/guptik_desktop"
fi

echo ""
echo "=== Verification Complete ==="
