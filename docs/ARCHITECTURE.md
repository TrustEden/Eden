# Architecture Documentation

## Overview

The Transcription & Diarization App follows a two-tier architecture:
- **Frontend**: Flutter desktop application (Windows)
- **Backend**: Python CLI script (WSL2/Ubuntu)

## Communication Flow

```
┌──────────────────────────────────────────────────────────────┐
│                     Flutter App (Windows)                    │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  User Interface Layer                                  │  │
│  │  - Material Design 3                                   │  │
│  │  - Tab-based navigation                                │  │
│  │  - Reactive state management                           │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Business Logic Layer                                  │  │
│  │  - File path conversion (Windows ↔ WSL)               │  │
│  │  - Progress tracking                                   │  │
│  │  - JSON data management                                │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Integration Layer                                     │  │
│  │  - process_run (Shell execution)                       │  │
│  │  - WSL command construction                            │  │
│  │  - Stream-based output parsing                         │  │
│  └────────────────────────────────────────────────────────┘  │
└───────────────────────────┬──────────────────────────────────┘
                            │
                 WSL Bash Command
                 "wsl bash -c '...'"
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                 Python Backend (WSL2/Ubuntu)                 │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Command Line Interface                                │  │
│  │  - Argument parsing (argparse)                         │  │
│  │  - Progress logging (stderr)                           │  │
│  │  - Error handling                                      │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  AI Model Layer                                        │  │
│  │  ┌──────────────────┐  ┌──────────────────┐            │  │
│  │  │ faster-whisper   │  │ pyannote.audio   │            │  │
│  │  │ (Transcription)  │  │ (Diarization)    │            │  │
│  │  │ - large-v3 model │  │ - speaker-3.1    │            │  │
│  │  │ - Word timestamps│  │ - Speaker labels │            │  │
│  │  └──────────────────┘  └──────────────────┘            │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Processing Pipeline                                   │  │
│  │  1. Load audio file                                    │  │
│  │  2. Transcribe → segments with word timestamps         │  │
│  │  3. Diarize → speaker segments                         │  │
│  │  4. Merge → aligned segments                           │  │
│  │  5. Format → full transcript                           │  │
│  │  6. Export → JSON output                               │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  CUDA/GPU Layer                                        │  │
│  │  - PyTorch with CUDA 12.9                              │  │
│  │  - Automatic device detection                          │  │
│  │  - Memory management                                   │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

## Component Details

### Frontend Components

#### UploadTab Widget
**Responsibilities**:
- File selection (file picker + drag-and-drop)
- Path conversion (Windows → WSL)
- WSL process execution
- Progress monitoring
- Log display

**Key Methods**:
- `_pickFile()`: Opens file picker dialog
- `_processFile()`: Executes WSL transcription command
- `_convertToWSLPath()`: Converts Windows paths to WSL format
- `_addLog()`: Manages processing log

**Data Flow**:
1. User selects file → `_selectedFilePath`
2. User clicks Process → `_processFile()`
3. Convert path → WSL format
4. Execute command → `wsl bash -c "..."`
5. Parse output → Update progress
6. Read JSON → Call `onComplete` callback

#### EditorTab Widget
**Responsibilities**:
- Display transcription
- Rich text editing (flutter_quill)
- Segment management
- Export to TXT/JSON

**Key Methods**:
- `_initializeEditor()`: Load transcript into Quill
- `_onTextChanged()`: Update segments on edit
- `_saveAsText()`: Export plain text
- `_saveAsJson()`: Export with metadata
- `_updateSegmentsFromText()`: Parse edited text back to segments

**State Management**:
- `QuillController`: Manages document state
- `transcriptionData`: Full JSON data
- `_hasUnsavedChanges`: Tracks modifications

#### HomeScreen Widget
**Responsibilities**:
- Tab navigation
- Cross-tab state sharing
- Data coordination

**State Flow**:
```
UploadTab._processFile()
  ↓
widget.onComplete(path, data)
  ↓
HomeScreen._onTranscriptionComplete()
  ↓
setState() → Update transcriptionData
  ↓
EditorTab receives new data via widget.transcriptionData
  ↓
EditorTab._initializeEditor()
```

### Backend Components

#### transcribe.py Main Script

**Function Breakdown**:

1. **`check_gpu()`**
   - Detects CUDA availability
   - Reports GPU specs
   - Returns boolean

2. **`load_models(use_gpu)`**
   - Loads Whisper model (large-v3)
   - Loads pyannote pipeline (speaker-diarization-3.1)
   - Configures device (CUDA/CPU)
   - Returns model instances

3. **`transcribe_audio(model, audio_path)`**
   - Processes audio through Whisper
   - Extracts segments with word timestamps
   - Applies VAD filtering
   - Returns segments list + duration

4. **`diarize_audio(pipeline, audio_path)`**
   - Identifies speaker segments
   - Labels speakers (SPEAKER_00, SPEAKER_01, etc.)
   - Returns speaker timeline

5. **`merge_transcription_and_diarization(trans_segs, speaker_segs)`**
   - Aligns transcription with speaker labels
   - Calculates segment overlaps
   - Assigns speaker to each utterance
   - Returns merged segments

6. **`create_full_transcript(segments)`**
   - Formats segments into readable text
   - Groups by speaker
   - Adds spacing between speakers
   - Returns formatted string

**Processing Pipeline**:
```
Input Audio File
  ↓
Load Models (10-30s first time)
  ↓
Transcribe Audio (1-3x realtime)
  ↓ (word-level segments)
Diarize Audio (0.5-1x realtime)
  ↓ (speaker segments)
Merge Segments (< 1s)
  ↓ (aligned data)
Format Transcript (< 1s)
  ↓
Write JSON Output
  ↓
Complete
```

## Data Structures

### Transcription Data JSON

```typescript
interface TranscriptionData {
  metadata: {
    filename: string;
    duration: number;
    processed_at: string;  // ISO 8601 format
    model_transcription: string;
    model_diarization: string;
    gpu_used: boolean;
  };
  segments: Segment[];
  full_transcript: string;
}

interface Segment {
  id: number;
  start: number;  // seconds
  end: number;    // seconds
  speaker: string;  // SPEAKER_00, SPEAKER_01, etc.
  text: string;
  words: Word[];
}

interface Word {
  word: string;
  start: number;  // seconds
  end: number;    // seconds
}
```

## Path Conversion

### Windows to WSL Path Mapping

```
Windows Path              WSL Path
─────────────────────────────────────────────────
C:\Users\Name\file.mp3 → /mnt/c/Users/Name/file.mp3
D:\Audio\test.wav      → /mnt/d/Audio/test.wav
```

**Algorithm**:
```dart
String _convertToWSLPath(String windowsPath) {
  if (windowsPath.length >= 2 && windowsPath[1] == ':') {
    final drive = windowsPath[0].toLowerCase();
    final pathPart = windowsPath.substring(2).replaceAll('\\', '/');
    return '/mnt/$drive$pathPart';
  }
  return windowsPath;
}
```

## GPU Acceleration

### Memory Usage

**Model Loading**:
- Whisper large-v3: ~3-4 GB VRAM
- Pyannote diarization: ~2-3 GB VRAM
- **Total**: ~5-7 GB VRAM required

**Processing**:
- Additional ~2-4 GB during active processing
- **Recommended**: 8+ GB VRAM
- **Optimal**: 16+ GB VRAM

### Performance Optimization

**CUDA Operations**:
- Automatic mixed precision (FP16)
- Batch processing where applicable
- Memory-efficient model loading
- Gradient computation disabled (inference only)

## Error Handling

### Frontend Error Cases

1. **File Not Selected**: Show snackbar
2. **WSL Not Available**: Command fails, show error dialog
3. **Process Timeout**: Shell timeout (default 2 min)
4. **Invalid JSON**: Parse error, show error
5. **File Access Denied**: Permission error

### Backend Error Cases

1. **GPU Not Available**: Fallback to CPU (slow)
2. **Model Download Failed**: Network error
3. **Invalid Audio File**: FFmpeg error
4. **Out of Memory**: CUDA OOM error
5. **HF Token Invalid**: Authentication error

## Security Considerations

1. **Path Injection**: Paths are quoted in shell commands
2. **Command Injection**: No user input in shell commands
3. **File Access**: Limited to user-selected files
4. **API Keys**: HF_TOKEN stored in WSL environment only
5. **Network**: Only HTTPS for model downloads

## Performance Benchmarks

### With RTX 5060 Ti (16GB VRAM)

| Audio Duration | Transcription | Diarization | Total    |
|---------------|---------------|-------------|----------|
| 5 minutes     | 2-3 min       | 1-2 min     | 3-5 min  |
| 30 minutes    | 10-15 min     | 5-10 min    | 15-25 min|
| 1 hour        | 20-30 min     | 10-20 min   | 30-50 min|

### CPU-Only Mode (Ryzen 5 2600)

| Audio Duration | Total Time      |
|---------------|-----------------|
| 5 minutes     | 30-45 min       |
| 30 minutes    | 3-4 hours       |
| 1 hour        | 6-8 hours       |

**Recommendation**: Always use GPU mode for practical usage.

## Future Architecture Improvements

1. **Streaming Processing**: Process audio in chunks for real-time feedback
2. **Caching Layer**: Cache loaded models between runs
3. **Queue System**: Process multiple files in sequence
4. **WebSocket Communication**: Replace shell execution with socket communication
5. **Docker Container**: Package backend as container for easier deployment
6. **REST API**: Backend as microservice for remote processing
7. **Database Storage**: Store processing history and results
8. **Multi-GPU Support**: Distribute processing across multiple GPUs

## Development Guidelines

### Adding New Features

1. **Frontend Changes**:
   - Add new widgets in `lib/screens/`
   - Update state management in parent widgets
   - Maintain Material Design guidelines

2. **Backend Changes**:
   - Add new functions in `transcribe.py`
   - Update JSON schema if needed
   - Maintain CLI compatibility

3. **Testing**:
   - Test GPU and CPU modes
   - Verify path conversion on different drives
   - Check error handling for edge cases
   - Validate JSON schema

### Code Style

**Dart/Flutter**:
- Follow official [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter analyze` for linting
- Prefer const constructors

**Python**:
- Follow [PEP 8](https://peps.python.org/pep-0008/)
- Use type hints where applicable
- Document functions with docstrings

## Dependencies

### Frontend
```yaml
flutter_quill: ^10.0.0   # Rich text editor
file_picker: ^8.0.0      # File selection
desktop_drop: ^0.4.4     # Drag and drop
process_run: ^1.1.0      # Shell execution
path_provider: ^2.1.0    # Path utilities
```

### Backend
```
torch (nightly)          # PyTorch with CUDA
faster-whisper>=1.0.0    # Whisper optimization
pyannote.audio>=3.0.0    # Speaker diarization
python-docx>=1.1.0       # DOCX export (future)
```

## Monitoring and Debugging

### Frontend Debugging
```bash
flutter run --verbose
flutter logs
```

### Backend Debugging
```bash
# In WSL2
source ~/transcription_env/bin/activate
python ~/transcription_app/transcribe.py --help

# Test with sample file
python ~/transcription_app/transcribe.py sample.mp3 --output test.json --no-gpu
```

### GPU Monitoring
```bash
# Watch GPU usage in real-time
watch -n 1 nvidia-smi

# Log GPU usage
nvidia-smi dmon -i 0
```
