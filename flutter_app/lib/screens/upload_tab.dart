import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:convert';
import 'dart:io';
import 'package:process_run/shell.dart';
import 'package:path_provider/path_provider.dart';

class UploadTab extends StatefulWidget {
  final Function(String jsonPath, Map<String, dynamic> data) onComplete;

  const UploadTab({super.key, required this.onComplete});

  @override
  State<UploadTab> createState() => _UploadTabState();
}

class _UploadTabState extends State<UploadTab> {
  String? _selectedFilePath;
  bool _isProcessing = false;
  String _statusMessage = 'Select or drop an audio file to begin';
  double _progress = 0.0;
  final List<String> _logMessages = [];
  bool _isDragging = false;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'ogg', 'flac', 'm4a', 'wma', 'aac'],
      allowMultiple: false,
    );

    if (result != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _statusMessage = 'File selected: ${result.files.single.name}';
        _logMessages.clear();
      });
    }
  }

  void _addLog(String message) {
    setState(() {
      _logMessages.add('[${DateTime.now().toString().substring(11, 19)}] $message');
      // Keep only last 20 messages
      if (_logMessages.length > 20) {
        _logMessages.removeAt(0);
      }
    });
  }

  Future<void> _processFile() async {
    if (_selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file first')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Initializing transcription...';
      _progress = 0.05;
      _logMessages.clear();
    });

    try {
      _addLog('Starting transcription process');

      // Get temp directory for output
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/transcription_output_$timestamp.json';

      _addLog('Output will be saved to: $outputPath');

      // Convert Windows path to WSL path
      final wslInputPath = _convertToWSLPath(_selectedFilePath!);
      final wslOutputPath = _convertToWSLPath(outputPath);

      _addLog('Input file (WSL): $wslInputPath');
      _addLog('Output file (WSL): $wslOutputPath');

      setState(() {
        _statusMessage = 'Activating Python environment...';
        _progress = 0.1;
      });

      // Prepare WSL command
      final shell = Shell();
      final command = 'wsl bash -c "source ~/transcription_env/bin/activate && '
          'python3 ~/transcription_app/transcribe.py '
          '"$wslInputPath" --output "$wslOutputPath""';

      _addLog('Executing transcription command');

      setState(() {
        _statusMessage = 'Loading AI models (this may take a while)...';
        _progress = 0.2;
      });

      // Run the command and capture output
      int lineCount = 0;
      await for (var line in shell.run(command)) {
        final output = line.toString();
        _addLog(output);

        // Update progress based on output
        if (output.contains('Loading faster-whisper')) {
          setState(() {
            _statusMessage = 'Loading Whisper model...';
            _progress = 0.3;
          });
        } else if (output.contains('Loading pyannote')) {
          setState(() {
            _statusMessage = 'Loading diarization model...';
            _progress = 0.4;
          });
        } else if (output.contains('Transcribing audio')) {
          setState(() {
            _statusMessage = 'Transcribing audio (this may take several minutes)...';
            _progress = 0.5;
          });
        } else if (output.contains('diarization')) {
          setState(() {
            _statusMessage = 'Identifying speakers...';
            _progress = 0.7;
          });
        } else if (output.contains('Merging')) {
          setState(() {
            _statusMessage = 'Merging transcription with speaker labels...';
            _progress = 0.85;
          });
        } else if (output.contains('SUCCESS')) {
          setState(() {
            _statusMessage = 'Processing complete!';
            _progress = 0.95;
          });
        }

        lineCount++;
      }

      setState(() {
        _statusMessage = 'Reading output file...';
        _progress = 0.97;
      });

      // Read the output JSON
      final outputFile = File(outputPath);
      if (!outputFile.existsSync()) {
        throw Exception('Output file was not created. Check WSL2 setup and logs.');
      }

      _addLog('Reading JSON output');
      final jsonString = await outputFile.readAsString();
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      _addLog('Transcription complete!');
      _addLog('Duration: ${jsonData['metadata']['duration']?.toStringAsFixed(1) ?? 'unknown'} seconds');
      _addLog('Segments: ${jsonData['segments']?.length ?? 0}');

      setState(() {
        _statusMessage = 'Complete! ✓';
        _progress = 1.0;
        _isProcessing = false;
      });

      // Notify parent
      widget.onComplete(outputPath, jsonData);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Transcription complete! Switch to Editor tab to view and edit.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      _addLog('ERROR: $e');

      setState(() {
        _statusMessage = 'Error occurred during processing';
        _isProcessing = false;
        _progress = 0.0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Error Details'),
                    content: SingleChildScrollView(
                      child: Text(e.toString()),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  String _convertToWSLPath(String windowsPath) {
    // Convert C:\Users\... to /mnt/c/Users/...
    if (windowsPath.length >= 2 && windowsPath[1] == ':') {
      final drive = windowsPath[0].toLowerCase();
      final pathPart = windowsPath.substring(2).replaceAll('\\', '/');
      return '/mnt/$drive$pathPart';
    }
    return windowsPath;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Drop zone
          Expanded(
            flex: 2,
            child: DropTarget(
              onDragEntered: (details) {
                setState(() {
                  _isDragging = true;
                });
              },
              onDragExited: (details) {
                setState(() {
                  _isDragging = false;
                });
              },
              onDragDone: (detail) {
                setState(() {
                  _isDragging = false;
                });
                if (detail.files.isNotEmpty) {
                  final file = detail.files.first;
                  final extension = file.path.split('.').last.toLowerCase();
                  final allowedExtensions = ['mp3', 'wav', 'ogg', 'flac', 'm4a', 'wma', 'aac'];

                  if (allowedExtensions.contains(extension)) {
                    setState(() {
                      _selectedFilePath = file.path;
                      _statusMessage = 'File dropped: ${file.name}';
                      _logMessages.clear();
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Invalid file type: .$extension\nAllowed: ${allowedExtensions.join(", ")}'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isDragging
                        ? Colors.blue
                        : (_selectedFilePath == null ? Colors.grey : Colors.green),
                    width: _isDragging ? 3 : 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: _isDragging
                      ? Colors.blue.withOpacity(0.1)
                      : (_selectedFilePath == null
                          ? Colors.grey.withOpacity(0.05)
                          : Colors.green.withOpacity(0.05)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _selectedFilePath == null ? Icons.cloud_upload : Icons.check_circle,
                      size: 80,
                      color: _selectedFilePath == null ? Colors.blue : Colors.green,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    if (_selectedFilePath != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          _selectedFilePath!.split(Platform.pathSeparator).last,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Full path: $_selectedFilePath',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (_isProcessing) ...[
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48.0),
                        child: LinearProgressIndicator(value: _progress),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Browse Files'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: (_isProcessing || _selectedFilePath == null) ? null : _processFile,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Process'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Log output
          if (_logMessages.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 8),
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.terminal, size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'Processing Log',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              setState(() {
                                _logMessages.clear();
                              });
                            },
                            tooltip: 'Clear log',
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _logMessages.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              _logMessages[index],
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
