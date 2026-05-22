# Enigma CryptoShelter

Military-grade local encryption and password manager.
100% offline. No cloud. No servers. Your data stays on your device.

## Features
- AES-256-GCM + ChaCha20-Poly1305 double-layer file encryption (.ultra)
- Local password vault (like Proton Pass, but offline)
- Single master password — derives all keys via PBKDF2
- Cipher Lab: encrypt/decrypt text with 4 algorithms
- Cyberpunk dark UI (Tk desktop)

## Requirements
- Ruby 3.0+
- Tcl/Tk installed

## Installation

### macOS
```bash
brew install tcl-tk
gem install bundler
bundle install
```

### Linux (Ubuntu/Debian)
```bash
sudo apt-get install tcl tk
gem install bundler
bundle install
```

### Windows
Install Ruby via RubyInstaller (check MSYS2 + Tk option), then:
```bash
ridk install
gem install bundler && bundle install
```

## Run
```bash
ruby main.rb
```

## Test
```bash
bundle exec rspec
```

## Build Executable

Uses [Tebako](https://github.com/tamatebako/tebako) —
packages the app + Ruby runtime into a single executable.
No Ruby required on the target machine.

### Install Tebako (once)
```bash
gem install tebako
```

### Linux / macOS
```bash
chmod +x package/build.sh
./package/build.sh
```
Output: `dist/enigma_cryptoshelter_linux` or `dist/enigma_cryptoshelter_mac`

### Windows
```cmd
package\build.bat
```
Output: `dist\enigma_cryptoshelter.exe`

### All platforms (via Docker)
```bash
./package/build_all.sh
```

### Notes
- First build downloads Ruby runtime (~5-10 min)
- Subsequent builds use cached runtime (~1-2 min)
- Target machines need **no Ruby, no gems, no dependencies**
- Vault file stored at: `~/.enigma_cryptoshelter/vault.dat`

## Architecture
```
Modular-Monolithic OOP | module Enigma namespace

app/core/       cipher, vault, file_lock, errors, key_master
app/ui/         Tk panels (cipher_lab, vault, file_lock)
utils/          shared utilities (file_handler, validator, password_generator)
spec/           RSpec tests (70%+ coverage)
```

## Security
- PBKDF2-HMAC-SHA256 with 600,000 iterations for key derivation
- AES-256-GCM: authenticated encryption (detects tampering)
- ChaCha20-Poly1305: authenticated encryption (Signal/WhatsApp standard)
- Vault file: 600 permissions, stored in `~/.enigma_cryptoshelter/`
- Offline-only: eliminates network attack surface entirely
