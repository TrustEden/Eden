@echo off
REM Transcription App Launcher
REM This script launches the Flutter application on Windows

echo ========================================
echo Transcription App Launcher
echo ========================================
echo.

REM Get the directory where this script is located
set SCRIPT_DIR=%~dp0

REM Navigate to the Flutter app directory
cd /d "%SCRIPT_DIR%"

REM Check if Flutter is installed
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter not found in PATH
    echo.
    echo Please install Flutter:
    echo 1. Download from https://flutter.dev/docs/get-started/install/windows
    echo 2. Extract to C:\flutter
    echo 3. Add C:\flutter\bin to your PATH
    echo 4. Run: flutter doctor
    echo.
    pause
    exit /b 1
)

echo Flutter found!
echo.

REM Check if dependencies are installed
if not exist "pubspec.lock" (
    echo Installing dependencies...
    flutter pub get
    echo.
)

echo Starting application...
echo.

REM Run the Flutter app
flutter run -d windows

pause
