import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const TranscriptionApp());
}

class TranscriptionApp extends StatelessWidget {
  const TranscriptionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transcription & Diarization',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
