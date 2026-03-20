#!/bin/bash

# Installation script for dns-to-mdns Homebrew formula
# This script installs the formula locally and optionally starts the service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMULA_NAME="dns-to-mdns"

echo "🔨 Installing $FORMULA_NAME Homebrew formula..."

# Tap the local formula
brew install --formula "$SCRIPT_DIR/$FORMULA_NAME.rb"

if [ $? -eq 0 ]; then
    echo "✅ Formula installed successfully!"
    echo ""
    echo "To start the service automatically at login, run:"
    echo "  brew services start $FORMULA_NAME"
    echo ""
    echo "To check service status:"
    echo "  brew services list"
    echo ""
    echo "To stop the service:"
    echo "  brew services stop $FORMULA_NAME"
else
    echo "❌ Installation failed"
    exit 1
fi
