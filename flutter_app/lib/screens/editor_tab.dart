import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

class EditorTab extends StatefulWidget {
  final String? jsonPath;
  final Map<String, dynamic>? transcriptionData;
  final Function(Map<String, dynamic> data) onUpdate;

  const EditorTab({
    super.key,
    this.jsonPath,
    this.transcriptionData,
    required this.onUpdate,
  });

  @override
  State<EditorTab> createState() => _EditorTabState();
}

class _EditorTabState extends State<EditorTab> {
  QuillController? _controller;
  final FocusNode _focusNode = FocusNode();
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _initializeEditor();
  }

  @override
  void didUpdateWidget(EditorTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transcriptionData != oldWidget.transcriptionData) {
      _initializeEditor();
    }
  }

  void _initializeEditor() {
    if (widget.transcriptionData != null) {
      final fullTranscript =
          widget.transcriptionData!['full_transcript'] as String? ?? '';
      final doc = Document()..insert(0, fullTranscript);

      // Dispose old controller if exists
      _controller?.removeListener(_onTextChanged);
      _controller?.dispose();

      _controller = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );

      // Listen for changes to update JSON
      _controller!.addListener(_onTextChanged);

      setState(() {
        _hasUnsavedChanges = false;
      });
    }
  }

  void _onTextChanged() {
    if (_controller != null && widget.transcriptionData != null) {
      // Update the full transcript in the data
      final newText = _controller!.document.toPlainText();
      final updatedData = Map<String, dynamic>.from(widget.transcriptionData!);
      updatedData['full_transcript'] = newText;

      // Also update individual segments if possible
      _updateSegmentsFromText(updatedData, newText);

      widget.onUpdate(updatedData);

      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  void _updateSegmentsFromText(Map<String, dynamic> data, String text) {
    // Parse the text to update segments
    // This is a simplified approach - splits by speaker labels
    final lines = text.split('\n');
    final segments = List<Map<String, dynamic>>.from(data['segments'] as List);
    int segmentIndex = 0;
    String currentSpeaker = '';
    List<String> currentLines = [];

    for (var line in lines) {
      if (line.trim().isEmpty) continue;

      // Check if line is a speaker label (ends with ':')
      if (line.trim().endsWith(':') && line.trim().length <= 15) {
        // Save previous segment if exists
        if (currentLines.isNotEmpty && segmentIndex < segments.length) {
          segments[segmentIndex]['text'] = currentLines.join(' ');
          segmentIndex++;
        }
        currentSpeaker = line.trim();
        currentLines = [];
      } else {
        currentLines.add(line.trim());
      }
    }

    // Save last segment
    if (currentLines.isNotEmpty && segmentIndex < segments.length) {
      segments[segmentIndex]['text'] = currentLines.join(' ');
    }

    data['segments'] = segments;
  }

  Future<void> _saveAsText() async {
    if (_controller == null) return;

    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save as Text',
      fileName: 'transcript.txt',
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (outputPath != null) {
      try {
        // Ensure .txt extension
        if (!outputPath.endsWith('.txt')) {
          outputPath = '$outputPath.txt';
        }

        final text = _controller!.document.toPlainText();
        await File(outputPath).writeAsString(text);

        setState(() {
          _hasUnsavedChanges = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Saved to: $outputPath'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving file: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveAsJson() async {
    if (widget.transcriptionData == null) return;

    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save as JSON',
      fileName: 'transcript.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (outputPath != null) {
      try {
        // Ensure .json extension
        if (!outputPath.endsWith('.json')) {
          outputPath = '$outputPath.json';
        }

        final jsonString =
            const JsonEncoder.withIndent('  ').convert(widget.transcriptionData);
        await File(outputPath).writeAsString(jsonString);

        setState(() {
          _hasUnsavedChanges = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Saved to: $outputPath'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving file: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showMetadata() {
    if (widget.transcriptionData == null) return;

    final metadata = widget.transcriptionData!['metadata'] as Map<String, dynamic>?;
    if (metadata == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transcription Metadata'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMetadataRow('Filename', metadata['filename']),
              _buildMetadataRow(
                'Duration',
                '${(metadata['duration'] as num?)?.toStringAsFixed(1) ?? 'unknown'} seconds',
              ),
              _buildMetadataRow('Processed At', metadata['processed_at']),
              _buildMetadataRow('Transcription Model', metadata['model_transcription']),
              _buildMetadataRow('Diarization Model', metadata['model_diarization']),
              _buildMetadataRow(
                'GPU Used',
                metadata['gpu_used'] == true ? 'Yes' : 'No',
              ),
              const Divider(),
              _buildMetadataRow(
                'Total Segments',
                '${(widget.transcriptionData!['segments'] as List?)?.length ?? 0}',
              ),
              _buildMetadataRow(
                'Word Count',
                _controller?.document.toPlainText().split(RegExp(r'\s+')).length.toString() ?? '0',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value?.toString() ?? 'N/A'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTextChanged);
    _controller?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transcriptionData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.edit_note_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No transcription loaded',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Process an audio file in the Upload tab',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[200],
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            children: [
              // Formatting toolbar
              if (_controller != null) ...[
                QuillToolbar.simple(
                  controller: _controller!,
                  configurations: const QuillSimpleToolbarConfigurations(
                    showAlignmentButtons: false,
                    showBackgroundColorButton: false,
                    showCenterAlignment: false,
                    showCodeBlock: false,
                    showColorButton: false,
                    showDirection: false,
                    showFontFamily: false,
                    showFontSize: false,
                    showHeaderStyle: false,
                    showIndent: false,
                    showInlineCode: false,
                    showJustifyAlignment: false,
                    showLeftAlignment: false,
                    showLink: false,
                    showListBullets: false,
                    showListCheck: false,
                    showListNumbers: false,
                    showQuote: false,
                    showRightAlignment: false,
                    showSearchButton: false,
                    showSmallButton: false,
                    showStrikeThrough: false,
                    showSubscript: false,
                    showSuperscript: false,
                    showUndo: true,
                    showRedo: true,
                  ),
                ),
              ],
              const Spacer(),

              // Unsaved changes indicator
              if (_hasUnsavedChanges)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.orange),
                      SizedBox(width: 4),
                      Text(
                        'Unsaved changes',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ],
                  ),
                ),

              // Action buttons
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: _showMetadata,
                tooltip: 'Show metadata',
              ),
              const VerticalDivider(),
              ElevatedButton.icon(
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save TXT'),
                onPressed: _saveAsText,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.code, size: 18),
                label: const Text('Save JSON'),
                onPressed: _saveAsJson,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),

        // Editor
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: _controller != null
                ? QuillEditor.basic(
                    controller: _controller!,
                    focusNode: _focusNode,
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }
}
