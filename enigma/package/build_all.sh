#!/bin/bash
# ==========================================================
# Build for ALL platforms using Tebako Docker images
# Requires Docker installed
# Usage: ./package/build_all.sh
# ==========================================================
set -e

APP_NAME="enigma_cryptoshelter"
RUBY_VERSION="3.2.2"

echo "Building for all platforms via Docker..."
mkdir -p dist

# Linux x86_64
echo "→ Linux x86_64"
docker run --rm \
  -v "$(pwd):/app" \
  -w /app \
  ghcr.io/tamatebako/tebako-ubuntu-20.04:latest \
  tebako press \
    --root . \
    --entry-point main.rb \
    --output "dist/${APP_NAME}_linux_x86_64" \
    --Ruby "${RUBY_VERSION}"

# macOS (requires macOS host or cross-compile)
echo "→ macOS (requires macOS host)"
echo "  Run ./package/build.sh on a Mac"

# Windows (requires Windows host or wine)
echo "→ Windows (requires Windows host)"
echo "  Run package\\build.bat on Windows"

echo ""
echo "✅ Linux build complete"
echo "   dist/${APP_NAME}_linux_x86_64"
