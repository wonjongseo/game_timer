import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class FancyTimerPage extends StatefulWidget {
  @override
  _FancyTimerPageState createState() => _FancyTimerPageState();
}

class _FancyTimerPageState extends State<FancyTimerPage> {
  // 기본 MP3(assets) 목록
  final List<String> _mp3Names = [
    "sounds/police-siren-1.mp3",
    "sounds/police-siren-2.mp3",
    "sounds/police-siren-3.mp3",
  ];
  // 전체 선택 가능 목록 (assets + 녹음 파일)
  List<String> _playList = [];
  String _selectedMp3 = "";

  // 녹음용 AudioRecorder
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecordingNow = false;
  String? _tempPath;

  // 타이머 설정
  Duration _pickedDuration = Duration(seconds: 10);
  Timer? _timer;
  int _remaining = 0;

  // 반복 옵션
  bool _isRepeating = false;
  bool _isUnlimited = true;
  final TextEditingController _repeatCountController =
      TextEditingController(text: '2');
  int _remainingRepeats = 0;

  // 사운드 지속시간 입력 (초)
  final TextEditingController _soundDurationController =
      TextEditingController(text: '3');

  // 오디오 플레이어
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _playList = List.from(_mp3Names);
    _selectedMp3 = _playList.first;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    _recorder.dispose();
    _repeatCountController.dispose();
    _soundDurationController.dispose();
    super.dispose();
  }

  // 타이머 Duration 선택 모달
  Future<void> _showDurationPicker() async {
    Duration? result = await showCupertinoModalPopup<Duration>(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: Colors.white,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                child: Text('완료'),
                onPressed: () => Navigator.of(context).pop(_pickedDuration),
              ),
            ),
            Expanded(
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.hms,
                initialTimerDuration: _pickedDuration,
                onTimerDurationChanged: (val) {
                  setState(() => _pickedDuration = val);
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _pickedDuration = result);
  }

  // 녹음 시작/중지 & 파일명 입력 팝업
  Future<void> _toggleRecording() async {
    if (_isRecordingNow) {
      // 녹음 중지
      final String? path = await _recorder.stop();
      setState(() => _isRecordingNow = false);
      if (path != null) {
        _tempPath = path;
        _showRenameDialog();
      }
    } else {
      // 녹음 시작 전 권한 확인
      if (!await _recorder.hasPermission()) return;
      final dir = await getApplicationDocumentsDirectory();
      final tmp = '${dir.path}/tmp_record.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: tmp,
      );
      setState(() => _isRecordingNow = true);
    }
  }

  // 파일명 입력 다이얼로그
  Future<void> _showRenameDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('저장할 파일명 입력'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: '확장자 없이 입력'),
        ),
        actions: [
          TextButton(
            child: Text('취소'),
            onPressed: () {
              Navigator.of(context).pop();
              _tempPath = null;
            },
          ),
          TextButton(
            child: Text('저장'),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty && _tempPath != null) {
                final dir = File(_tempPath!).parent;
                final newPath = '${dir.path}/$name.m4a'; // fixed interpolation
                await File(_tempPath!).rename(newPath);
                _playList.add(newPath);
                setState(() => _selectedMp3 = newPath);
              }
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // 알람 재생
  Future<void> _playAlarmOnce() async {
    final soundSeconds = int.tryParse(_soundDurationController.text) ?? 3;
    if (_selectedMp3.startsWith('sounds/')) {
      await _audioPlayer.play(AssetSource(_selectedMp3));
    } else {
      await _audioPlayer.play(DeviceFileSource(_selectedMp3));
    }
    Future.delayed(Duration(seconds: soundSeconds), () {
      _audioPlayer.stop();
    });
  }

  // 타이머 로직
  void _startTimer() {
    final interval = _pickedDuration.inSeconds;
    if (interval <= 0) return;
    if (_isRepeating && !_isUnlimited) {
      final count = int.tryParse(_repeatCountController.text) ?? 0;
      _remainingRepeats = count > 0 ? count : 0;
      if (_remainingRepeats == 0) return;
    }
    _timer?.cancel();
    setState(() => _remaining = interval);
    _timer = Timer.periodic(Duration(seconds: 1), (t) async {
      final next = _remaining - 1;
      if (next <= 0) {
        await _playAlarmOnce();
        if (_isRepeating) {
          if (_isUnlimited)
            setState(() => _remaining = interval);
          else {
            _remainingRepeats--;
            if (_remainingRepeats > 0)
              setState(() => _remaining = interval);
            else {
              t.cancel();
              setState(() => _remaining = 0);
            }
          }
        } else {
          t.cancel();
          setState(() => _remaining = 0);
        }
      } else
        setState(() => _remaining = next);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _audioPlayer.stop();
    setState(() {
      _remaining = 0;
      _remainingRepeats = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(_pickedDuration.inHours),
        m = two(_pickedDuration.inMinutes.remainder(60)),
        s = two(_pickedDuration.inSeconds.remainder(60));
    return Scaffold(
      appBar: AppBar(title: Text('Fancy Timer')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 타이머 선택
          GestureDetector(
            onTap: _showDurationPicker,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueGrey),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('$h:$m:$s',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(height: 16),
          // 사운드 선택
          Text('알람 사운드 선택', style: TextStyle(fontSize: 16)),
          DropdownButton<String>(
              value: _selectedMp3,
              isExpanded: true,
              items: _playList.map((path) {
                final label = path.startsWith('sounds/')
                    ? path.split('/').last
                    : File(path).uri.pathSegments.last;
                return DropdownMenuItem(value: path, child: Text(label));
              }).toList(),
              onChanged: (v) => setState(() => _selectedMp3 = v!)),
          SizedBox(height: 8),
          // 녹음 토글: 녹음 중지 시 파일명 입력 팝업
          ElevatedButton.icon(
            icon: Icon(_isRecordingNow ? Icons.stop : Icons.mic),
            label: Text(_isRecordingNow ? '녹음 중지(저장)' : '새로 녹음하기'),
            onPressed: _toggleRecording,
          ),
          SizedBox(height: 16),
          // 반복 옵션
          CheckboxListTile(
              title: Text('반복하기'),
              value: _isRepeating,
              onChanged: (v) => setState(() => _isRepeating = v!)),
          if (_isRepeating) ...[
            Row(children: [
              Expanded(
                  child: RadioListTile<bool>(
                      title: Text('무제한'),
                      value: true,
                      groupValue: _isUnlimited,
                      onChanged: (v) => setState(() => _isUnlimited = v!))),
              Expanded(
                  child: RadioListTile<bool>(
                      title: Text('횟수 지정'),
                      value: false,
                      groupValue: _isUnlimited,
                      onChanged: (v) => setState(() => _isUnlimited = v!))),
            ]),
            if (!_isUnlimited)
              TextField(
                  controller: _repeatCountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: '반복 횟수', border: OutlineInputBorder())),
          ],
          SizedBox(height: 16),
          // 사운드 지속시간
          Text('사운드 재생 시간(초)', style: TextStyle(fontSize: 16)),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _soundDurationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(border: OutlineInputBorder()))),
            SizedBox(width: 8),
            Text('초'),
          ]),
          SizedBox(height: 16),
          // 실행/중지 버튼
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton(onPressed: _startTimer, child: Text('실행')),
            SizedBox(width: 16),
            ElevatedButton(onPressed: _stopTimer, child: Text('중지')),
          ]),
          if (_remaining > 0) ...[
            SizedBox(height: 24),
            Text('남은 시간: $_remaining 초', style: TextStyle(fontSize: 18)),
            if (_isRepeating && !_isUnlimited)
              Text('남은 반복 횟수: $_remainingRepeats',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ]),
      ),
    );
  }
}
