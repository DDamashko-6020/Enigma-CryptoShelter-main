#!/bin/bash
set -e
mkdir -p dist
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
OUT="dist/enigma_cryptoshelter_${OS}"
tebako press --root . --entry-point main.rb --output "$OUT" --Ruby 3.2.2
chmod +x "$OUT"
echo "✅ Built: $OUT"
