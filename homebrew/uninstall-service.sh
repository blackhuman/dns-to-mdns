#!/bin/bash

# Uninstall script for dns-to-mdns service
# Removes both Homebrew formula and manual launchctl service

set -e

echo "🗑️  Uninstalling dns-to-mdns service..."

# Try to stop Homebrew service first
if brew services list 2>/dev/null | grep -q "dns-to-mdns"; then
    echo "Stopping Homebrew service..."
    brew services stop dns-to-mdns 2>/dev/null || true
fi

# Try to unload manual launchctl service
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
if [ -f "$LAUNCH_AGENTS_DIR/com.dns-to-mdns.plist" ]; then
    echo "Unloading manual launchctl service..."
    launchctl unload -w "$LAUNCH_AGENTS_DIR/com.dns-to-mdns.plist" 2>/dev/null || true
    rm -f "$LAUNCH_AGENTS_DIR/com.dns-to-mdns.plist"
fi

# Uninstall Homebrew formula if installed
if brew list --formula 2>/dev/null | grep -q "dns-to-mdns"; then
    echo "Removing Homebrew formula..."
    brew uninstall dns-to-mdns 2>/dev/null || true
fi

echo "✅ dns-to-mdns service uninstalled successfully!"
