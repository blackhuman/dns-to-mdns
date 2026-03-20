#!/bin/bash
# Release automation script for dns-to-mdns

set -e # Exit on error
set -x # Print each command before executing it

# 1. Check if version is provided
if [ -z "$1" ]; then
    echo "Usage: ./release.sh <version>"
    echo "Example: ./release.sh v0.1.0"
    exit 1
fi

VERSION=$1

# 2. Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed."
    echo "Install it with: brew install gh"
    exit 1
fi

# 3. Check if there are uncommitted changes
# if ! git diff-index --quiet HEAD --; then
#     echo "Error: You have uncommitted changes. Please commit or stash them first."
#     exit 1
# fi

# 4. Push current state to GitHub
CURRENT_BRANCH=$(git branch --show-current)
echo "🆙 Pushing current branch '$CURRENT_BRANCH' to origin..."
git push origin "$CURRENT_BRANCH"

# 5. Build and package the binary (Universal for macOS)
echo "🏗️  Building universal release binary (arm64 + x86_64)..."
swift build -c release --disable-sandbox --arch arm64 --arch x86_64

echo "📦 Packaging binary..."
# Standard naming convention: {app}-{version}-{os}-{arch}
OS="darwin"
ARCH="universal"
CLEAN_VERSION=$(echo "$VERSION" | sed 's/^v//')
ASSET_NAME="dns-to-mdns-${CLEAN_VERSION}-${OS}-${ARCH}.tar.gz"

# Archive the binary
tar -czf "$ASSET_NAME" -C .build/apple/Products/Release dns-to-mdns

# 6. Create the release with the asset
echo "🚀 Creating release $VERSION with asset: $ASSET_NAME..."

# This command will:
# - Create a tag if it doesn't exist
# - Push it to GitHub
# - Create a GitHub Release
# - Upload the binary asset
# - Generate release notes automatically
gh release create "$VERSION" "./$ASSET_NAME" --generate-notes

# Cleanup
rm "$ASSET_NAME"

echo "✅ Release $VERSION created successfully with binary asset!"
echo "🔄 The Homebrew formula update workflow should start automatically on GitHub."
