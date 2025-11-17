import 'package:flutter/material.dart';
import 'upload_tab.dart';
import 'editor_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? jsonPath;
  Map<String, dynamic>? transcriptionData;

  void _onTranscriptionComplete(String path, Map<String, dynamic> data) {
    setState(() {
      jsonPath = path;
      transcriptionData = data;
    });
  }

  void _onTranscriptionUpdate(Map<String, dynamic> data) {
    setState(() {
      transcriptionData = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.mic),
              SizedBox(width: 8),
              Text('Transcription & Diarization'),
            ],
          ),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.upload_file),
                text: 'Upload & Process',
              ),
              Tab(
                icon: Icon(Icons.edit_note),
                text: 'Edit Transcript',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            UploadTab(onComplete: _onTranscriptionComplete),
            EditorTab(
              jsonPath: jsonPath,
              transcriptionData: transcriptionData,
              onUpdate: _onTranscriptionUpdate,
            ),
          ],
        ),
      ),
    );
  }
}
