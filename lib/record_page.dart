import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class RecorderPage extends StatefulWidget {
  @override
  _RecorderPageState createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _filePath;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc, // ← 수정된 부분
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    setState(() {
      _isRecording = true;
      _filePath = path;
    });
  }

  Future<void> _stopRecording() async {
    await _recorder.stop();
    setState(() => _isRecording = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('녹음 완료: $_filePath')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('녹음 기능 예제')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(_isRecording ? '녹음 중지' : '녹음 시작'),
              style: ElevatedButton.styleFrom(
                  // primary: _isRecording ? Colors.red : Colors.blue,
                  ),
              onPressed: _isRecording ? _stopRecording : _startRecording,
            ),
            if (_filePath != null && !_isRecording)
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  '저장된 파일:\n$_filePath',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
