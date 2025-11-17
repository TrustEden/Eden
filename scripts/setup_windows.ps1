# Windows Setup Script for Transcription App
# Run this in PowerShell as Administrator

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Transcription App - Windows Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Running as Administrator" -ForegroundColor Green
Write-Host ""

# Check if WSL2 is installed
Write-Host "Checking WSL2 installation..." -ForegroundColor Yellow
$wslStatus = wsl --status 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "WSL2 not found. Installing WSL2..." -ForegroundColor Yellow
    wsl --install -d Ubuntu-24.04
    wsl --set-default-version 2

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "WSL2 Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "IMPORTANT: You need to restart your computer." -ForegroundColor Yellow
    Write-Host "After restart:" -ForegroundColor Yellow
    Write-Host "1. Open Ubuntu from Start Menu" -ForegroundColor Yellow
    Write-Host "2. Create a user account when prompted" -ForegroundColor Yellow
    Write-Host "3. Run this script again" -ForegroundColor Yellow
    Write-Host ""

    $restart = Read-Host "Restart now? (Y/N)"
    if ($restart -eq 'Y' -or $restart -eq 'y') {
        Restart-Computer
    }
    exit 0
} else {
    Write-Host "✓ WSL2 is already installed" -ForegroundColor Green
}

# Check if Ubuntu is installed
Write-Host ""
Write-Host "Checking Ubuntu installation..." -ForegroundColor Yellow
$distros = wsl -l -v
if ($distros -match "Ubuntu") {
    Write-Host "✓ Ubuntu is installed" -ForegroundColor Green
} else {
    Write-Host "Installing Ubuntu 24.04..." -ForegroundColor Yellow
    wsl --install -d Ubuntu-24.04
    Write-Host "✓ Ubuntu installed. Please set up your username and password." -ForegroundColor Green
}

# Check Flutter installation
Write-Host ""
Write-Host "Checking Flutter installation..." -ForegroundColor Yellow
$flutterPath = Get-Command flutter -ErrorAction SilentlyContinue

if ($null -eq $flutterPath) {
    Write-Host "WARNING: Flutter not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Flutter:" -ForegroundColor Yellow
    Write-Host "1. Download from https://flutter.dev/docs/get-started/install/windows" -ForegroundColor Yellow
    Write-Host "2. Extract to C:\flutter" -ForegroundColor Yellow
    Write-Host "3. Add C:\flutter\bin to your PATH" -ForegroundColor Yellow
    Write-Host "4. Run: flutter doctor" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "✓ Flutter is installed at: $($flutterPath.Source)" -ForegroundColor Green

    # Run flutter doctor
    Write-Host ""
    Write-Host "Running flutter doctor..." -ForegroundColor Yellow
    flutter doctor
}

# Now set up WSL2 environment
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Setting up WSL2 environment..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Copying setup script to WSL2..." -ForegroundColor Yellow

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

# Copy the setup script to WSL2 home directory
wsl cp "$projectRoot/scripts/setup_wsl2.sh" ~/setup_wsl2.sh
wsl chmod +x ~/setup_wsl2.sh

# Copy backend files
wsl mkdir -p ~/transcription_app_source
wsl cp "$projectRoot/backend/transcribe.py" ~/transcription_app_source/
wsl cp "$projectRoot/backend/test_gpu.py" ~/transcription_app_source/
wsl cp "$projectRoot/backend/requirements.txt" ~/transcription_app_source/

Write-Host "✓ Files copied to WSL2" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Running WSL2 setup script..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Run the setup script in WSL2
wsl bash ~/setup_wsl2.sh

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ Windows Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Navigate to the flutter_app directory" -ForegroundColor Yellow
Write-Host "2. Run: flutter pub get" -ForegroundColor Yellow
Write-Host "3. Run: flutter run -d windows" -ForegroundColor Yellow
Write-Host ""
