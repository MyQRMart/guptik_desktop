#!/bin/bash
# GupTik Desktop Cross-Platform Uninstallation
set -e

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    OS="windows"
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

echo "--- GupTik Desktop Uninstallation ($OS) ---"

if [ "$OS" == "linux" ]; then
    bash .flutter-install-scripts/linux-uninstall.sh
elif [ "$OS" == "macos" ]; then
    bash .flutter-install-scripts/macos-uninstall.sh
else
    powershell -ExecutionPolicy Bypass -File .flutter-install-scripts/windows-uninstall.ps1
fi