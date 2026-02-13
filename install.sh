#!/bin/bash
# GupTik Desktop Cross-Platform Installation
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

echo "--- GupTik Desktop Installation ($OS) ---"

if [ "$OS" == "linux" ]; then
    bash .flutter-install-scripts/linux-install.sh
elif [ "$OS" == "macos" ]; then
    bash .flutter-install-scripts/macos-install.sh
else
    powershell -ExecutionPolicy Bypass -File .flutter-install-scripts/windows-install.ps1
fi