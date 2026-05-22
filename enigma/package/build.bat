@echo off
REM =============================================
REM  ENIGMA CRYPTOSHELTER - Windows Build Script
REM  Packager: ocran (Windows-native)
REM =============================================
mkdir dist 2>nul

set "PATH=C:\Ruby40-x64\msys64\ucrt64\bin;%PATH%"

ocran main.rb ^
  --windows ^
  --gemfile Gemfile ^
  --chdir-first ^
  --no-autoload ^
  --icon enigma_icon.ico ^
  --output dist\enigma_cryptoshelter.exe

if %ERRORLEVEL% equ 0 (
  echo.
  echo =============================================
  echo  BUILD OK: dist\enigma_cryptoshelter.exe
  echo =============================================
) else (
  echo.
  echo =============================================
  echo  BUILD FAILED (code: %ERRORLEVEL%)
  echo =============================================
  exit /b %ERRORLEVEL%
)
