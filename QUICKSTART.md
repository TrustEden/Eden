# Quick Start Guide

Get up and running with the Transcription & Diarization App in 15 minutes.

## Prerequisites

- Windows 11
- NVIDIA GPU (RTX series recommended)
- 16GB+ RAM
- 10GB free disk space

## Step-by-Step Setup

### 1. Install WSL2 (5 minutes)

Open PowerShell as Administrator:

```powershell
wsl --install -d Ubuntu-24.04
```

**Restart your computer when prompted.**

After restart, open Ubuntu from Start Menu and create your username/password.

### 2. Run Setup Script (5-10 minutes)

In PowerShell (as Administrator):

```powershell
cd path\to\Eden
.\scripts\setup_windows.ps1
```

This will automatically:
- Install CUDA toolkit
- Set up Python environment
- Install all dependencies
- Test GPU

### 3. Configure Hugging Face (2 minutes)

1. Go to [https://huggingface.co/pyannote/speaker-diarization-3.1](https://huggingface.co/pyannote/speaker-diarization-3.1)
2. Click "Agree and access repository"
3. Go to [https://huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)
4. Create a new token (or copy existing one)

In WSL2:

```bash
echo "export HF_TOKEN='your_token_here'" >> ~/.bashrc
source ~/.bashrc
```

### 4. Install Flutter Dependencies (1 minute)

```bash
cd flutter_app
flutter pub get
```

### 5. Launch the App

Double-click `flutter_app/launch_app.bat` or run:

```bash
cd flutter_app
flutter run -d windows
```

## First Transcription

1. Click "Browse Files" or drag & drop an audio file
2. Click "Process"
3. Wait for completion (first run downloads models ~5GB)
4. Switch to "Edit Transcript" tab
5. Edit and save your transcript

## Troubleshooting

### GPU not detected?

```bash
# In WSL2
nvidia-smi
```

If this fails:
- Update Windows to latest version
- Update NVIDIA drivers
- Ensure WSL2 GPU support is enabled

### Models not downloading?

- Check internet connection
- Verify HF_TOKEN is set: `echo $HF_TOKEN`
- Ensure you accepted the pyannote agreement

### Flutter errors?

```bash
flutter clean
flutter pub get
flutter doctor
```

## Performance Tips

- First transcription is slower (model download)
- Close GPU-intensive apps during processing
- Use GPU mode for best performance
- Expect ~30-40 min for 1 hour of audio

## Next Steps

- Read the full [README.md](README.md) for detailed information
- Check the [docs](docs/) folder for advanced usage
- Test the backend directly: see README.md "Testing Backend Standalone"

## Getting Help

If you encounter issues:
1. Check the Troubleshooting section in README.md
2. Verify GPU is working: `python ~/transcription_app/test_gpu.py`
3. Open an issue on GitHub with error logs

---

**Estimated Total Setup Time**: 15-20 minutes (plus model download on first run)
