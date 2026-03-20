#!/bin/bash

# Manual installation script for launchctl service
# Use this if you don't want to use Homebrew services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_FILE="$SCRIPT_DIR/com.dns-to-mdns.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

echo "🔧 Installing dns-to-mdns launchctl service..."

# Create LaunchAgents directory if it doesn't exist
mkdir -p "$LAUNCH_AGENTS_DIR"

# Copy plist file
cp "$PLIST_FILE" "$LAUNCH_AGENTS_DIR/"

# Update plist path to point to actual binary location
if command -v dns-to-mdns &> /dev/null; then
    BINARY_PATH=$(which dns-to-mdns)
    echo "📍 Found dns-to-mdns at: $BINARY_PATH"
    
    # Update the plist with correct binary path
    sed -i '' "s|/usr/local/bin/dns-to-mdns|$BINARY_PATH|g" "$LAUNCH_AGENTS_DIR/com.dns-to-mdns.plist"
else
    echo "⚠️  Warning: dns-to-mdns not found in PATH"
    echo "Please ensure dns-to-mdns is installed and in your PATH"
    exit 1
fi

# Load the service
launchctl load -w "$LAUNCH_AGENTS_DIR/com.dns-to-mdns.plist"

if [ $? -eq 0 ]; then
    echo "✅ Service installed and started successfully!"
    echo ""
    echo "To check service status:"
    echo "  launchctl list | grep com.dns-to-mdns"
    echo ""
    echo "To view logs:"
    echo "  tail -f /tmp/dns-to-mdns.log"
    echo ""
    echo "To stop the service:"
    echo "  launchctl unload -w $LAUNCH_AGENTS_DIR/com.dns-to-mdns.plist"
    echo ""
    echo "To remove the service:"
    echo "  rm $LAUNCH_AGENTS_DIR/com.dns-to-mdns.plist"
else
    echo "❌ Failed to load service"
    exit 1
fi
