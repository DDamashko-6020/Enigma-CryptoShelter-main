@echo off
mkdir dist 2>nul
tebako press --root . --entry-point main.rb ^
  --output dist\enigma_cryptoshelter.exe --Ruby 3.2.2
echo Done: dist\enigma_cryptoshelter.exe
