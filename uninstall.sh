#!/bin/bash

# GupTik Desktop Cross-Platform Uninstallation Script
# Detects OS and uninstalls the application appropriately

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    OS="windows"
else
    echo "Unsupported operating system: $OSTYPE"
    exit 1
fi

echo "=== GupTik Desktop Uninstallation ==="
echo "Detected OS: $OS"
echo ""

# Check if we're in the correct directory
if [ ! -f "pubspec.yaml" ]; then
    echo "Error: pubspec.yaml not found. Please run this script from the project root."
    exit 1
fi

# Run platform-specific uninstallation script
if [ "$OS" == "linux" ]; then
    bash .flutter-install-scripts/linux-uninstall.sh
elif [ "$OS" == "macos" ]; then
    bash .flutter-install-scripts/macos-uninstall.sh
else
    echo "For Windows uninstallation, please run: .flutter-install-scripts\windows-uninstall.ps1"
    echo "Use PowerShell with: powershell -ExecutionPolicy Bypass -File .flutter-install-scripts/windows-uninstall.ps1"
    exit 1
fi
