#!/bin/bash
# WSL2 Setup Script for Transcription App
# This script sets up the Python environment, CUDA, and all dependencies

set -e  # Exit on error

echo "========================================"
echo "Transcription App - WSL2 Setup"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running in WSL2
if ! grep -qi microsoft /proc/version; then
    echo -e "${RED}ERROR: This script must be run in WSL2${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Running in WSL2${NC}"
echo ""

# Update system packages
echo "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install Python 3.11 and dependencies
echo ""
echo "Installing Python 3.11..."
sudo apt-get install -y python3.11 python3.11-venv python3-pip git

# Check if CUDA toolkit is installed
echo ""
if ! command -v nvcc &> /dev/null; then
    echo -e "${YELLOW}CUDA Toolkit not found. Installing...${NC}"

    # Download and install CUDA keyring
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
    sudo dpkg -i cuda-keyring_1.1-1_all.deb
    rm cuda-keyring_1.1-1_all.deb

    # Update and install CUDA toolkit
    sudo apt-get update
    sudo apt-get install -y cuda-toolkit-12-8

    # Add CUDA to PATH
    echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc

    echo -e "${GREEN}✓ CUDA Toolkit installed${NC}"
else
    echo -e "${GREEN}✓ CUDA Toolkit already installed${NC}"
fi

# Create virtual environment
echo ""
echo "Creating Python virtual environment..."
VENV_DIR="$HOME/transcription_env"

if [ -d "$VENV_DIR" ]; then
    echo -e "${YELLOW}Virtual environment already exists. Skipping creation.${NC}"
else
    python3.11 -m venv "$VENV_DIR"
    echo -e "${GREEN}✓ Virtual environment created at $VENV_DIR${NC}"
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Upgrade pip
echo ""
echo "Upgrading pip..."
pip install --upgrade pip

# Install PyTorch with CUDA support
echo ""
echo "Installing PyTorch with CUDA 12.9 support..."
echo "This may take several minutes..."
pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu129

# Install transcription dependencies
echo ""
echo "Installing faster-whisper and pyannote.audio..."
pip install faster-whisper
pip install pyannote.audio

# Install additional utilities
echo ""
echo "Installing additional utilities..."
pip install python-docx

# Create transcription app directory
echo ""
APP_DIR="$HOME/transcription_app"
if [ ! -d "$APP_DIR" ]; then
    mkdir -p "$APP_DIR"
    echo -e "${GREEN}✓ Created app directory at $APP_DIR${NC}"
else
    echo -e "${YELLOW}App directory already exists at $APP_DIR${NC}"
fi

# Copy Python scripts
echo ""
echo "Copying Python scripts..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
cp "$SCRIPT_DIR/backend/transcribe.py" "$APP_DIR/"
cp "$SCRIPT_DIR/backend/test_gpu.py" "$APP_DIR/"
chmod +x "$APP_DIR/transcribe.py"
chmod +x "$APP_DIR/test_gpu.py"
echo -e "${GREEN}✓ Scripts copied to $APP_DIR${NC}"

# Test GPU
echo ""
echo "========================================"
echo "Testing GPU Detection..."
echo "========================================"
python "$APP_DIR/test_gpu.py"

# Check for Hugging Face token
echo ""
echo "========================================"
echo "Hugging Face Setup"
echo "========================================"
if [ -z "$HF_TOKEN" ]; then
    echo -e "${YELLOW}WARNING: HF_TOKEN environment variable not set${NC}"
    echo ""
    echo "To use pyannote.audio, you need to:"
    echo "1. Create an account at https://huggingface.co"
    echo "2. Accept the user agreement at https://huggingface.co/pyannote/speaker-diarization-3.1"
    echo "3. Get your token from https://huggingface.co/settings/tokens"
    echo "4. Add to ~/.bashrc: export HF_TOKEN='your_token_here'"
    echo ""
    read -p "Enter your Hugging Face token now (or press Enter to skip): " token
    if [ ! -z "$token" ]; then
        echo "export HF_TOKEN='$token'" >> ~/.bashrc
        export HF_TOKEN="$token"
        echo -e "${GREEN}✓ HF_TOKEN added to ~/.bashrc${NC}"
    else
        echo -e "${YELLOW}Skipped. You'll need to set HF_TOKEN manually later.${NC}"
    fi
else
    echo -e "${GREEN}✓ HF_TOKEN is already set${NC}"
fi

# Add activation helper to bashrc
echo ""
echo "Adding activation helper to ~/.bashrc..."
if ! grep -q "alias activate-transcription" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Transcription App" >> ~/.bashrc
    echo "alias activate-transcription='source $VENV_DIR/bin/activate'" >> ~/.bashrc
    echo -e "${GREEN}✓ Added alias 'activate-transcription' to ~/.bashrc${NC}"
fi

echo ""
echo "========================================"
echo "✅ Setup Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Close and reopen your terminal (or run: source ~/.bashrc)"
echo "2. Activate the environment: activate-transcription"
echo "3. Set HF_TOKEN if you haven't already (see above)"
echo "4. Test transcription with: python ~/transcription_app/transcribe.py <audio_file> --output output.json"
echo ""
