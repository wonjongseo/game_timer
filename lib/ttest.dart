import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class FancyTimerPage extends StatefulWidget {
  @override
  _FancyTimerPageState createState() => _FancyTimerPageState();
}

class _FancyTimerPageState extends State<FancyTimerPage> {
  // 재생할 MP3 파일 목록
  final List<String> mp3Names = [
    "sounds/police-siren-1.mp3",
    "sounds/police-siren-2.mp3",
    "sounds/police-siren-3.mp3",
  ];
  String _selectedMp3 = "sounds/police-siren-1.mp3";

  Duration _pickedDuration = Duration(seconds: 10);
  Timer? _timer;
  int _remaining = 0;

  // 반복 관련 상태
  bool _isRepeating = false;
  bool _isUnlimited = true;
  final TextEditingController _repeatCountController =
      TextEditingController(text: '2');

  // 사운드 재생 지속시간 입력 컨트롤러 (기본 3초)
  final TextEditingController _soundDurationController =
      TextEditingController(text: '3');

  final AudioPlayer _audioPlayer = AudioPlayer();

  // 남은 반복 횟수
  int _remainingRepeats = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    _repeatCountController.dispose();
    _soundDurationController.dispose();
    super.dispose();
  }

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

  Future<void> _playAlarmOnce() async {
    final soundSeconds = int.tryParse(_soundDurationController.text) ?? 3;
    await _audioPlayer.play(AssetSource(_selectedMp3));
    Future.delayed(Duration(seconds: soundSeconds), () {
      _audioPlayer.stop();
    });
  }

  void _startTimer() {
    final interval = _pickedDuration.inSeconds;
    if (interval <= 0) return;

    // 반복 횟수 초기화
    if (_isRepeating && !_isUnlimited) {
      final input = int.tryParse(_repeatCountController.text);
      _remainingRepeats = (input != null && input > 0) ? input : 0;
      if (_remainingRepeats == 0) return;
    }

    _timer?.cancel();
    setState(() => _remaining = interval);

    _timer = Timer.periodic(Duration(seconds: 1), (t) async {
      final next = _remaining - 1;

      if (next <= 0) {
        // 알람 재생
        await _playAlarmOnce();

        if (_isRepeating) {
          // 반복 모드
          if (_isUnlimited) {
            setState(() => _remaining = interval);
          } else {
            _remainingRepeats--;
            if (_remainingRepeats > 0) {
              setState(() => _remaining = interval);
            } else {
              t.cancel();
              setState(() => _remaining = 0);
            }
          }
        } else {
          t.cancel();
          setState(() => _remaining = 0);
        }
      } else {
        setState(() => _remaining = next);
      }
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
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final h = twoDigits(_pickedDuration.inHours);
    final m = twoDigits(_pickedDuration.inMinutes.remainder(60));
    final s = twoDigits(_pickedDuration.inSeconds.remainder(60));

    return Scaffold(
      appBar: AppBar(title: Text('Fancy Timer')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 타이머 선택부
            GestureDetector(
              onTap: _showDurationPicker,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueGrey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$h:$m:$s',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            SizedBox(height: 16),

            // MP3 선택 드롭다운
            Text('알람 사운드 선택', style: TextStyle(fontSize: 16)),
            DropdownButton<String>(
              value: _selectedMp3,
              isExpanded: true,
              items: mp3Names
                  .map((name) => DropdownMenuItem(
                        value: name,
                        child: Text(name.split('/').last),
                      ))
                  .toList(),
              onChanged: (val) => setState(() {
                if (val != null) _selectedMp3 = val;
              }),
            ),

            SizedBox(height: 16),

            // 반복 여부 토글
            CheckboxListTile(
              title: Text('반복하기'),
              value: _isRepeating,
              onChanged: (v) => setState(() => _isRepeating = v!),
            ),

            if (_isRepeating) ...[
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text('무제한'),
                      value: true,
                      groupValue: _isUnlimited,
                      onChanged: (v) => setState(() => _isUnlimited = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text('횟수 지정'),
                      value: false,
                      groupValue: _isUnlimited,
                      onChanged: (v) => setState(() => _isUnlimited = v!),
                    ),
                  ),
                ],
              ),
              if (!_isUnlimited)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: TextField(
                    controller: _repeatCountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '반복 횟수',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
            ],

            SizedBox(height: 16),

            // 사운드 지속시간 입력
            Text('사운드 재생 시간(초)', style: TextStyle(fontSize: 16)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _soundDurationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text('초', style: TextStyle(fontSize: 16)),
              ],
            ),

            SizedBox(height: 16),

            // 실행/중지 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: _startTimer, child: Text('실행')),
                SizedBox(width: 16),
                ElevatedButton(onPressed: _stopTimer, child: Text('중지')),
              ],
            ),

            // 남은 시간 & 남은 반복 횟수 표시
            if (_remaining > 0) ...[
              SizedBox(height: 24),
              Text('남은 시간: $_remaining 초', style: TextStyle(fontSize: 18)),
              if (_isRepeating && !_isUnlimited)
                Text('남은 반복 횟수: $_remainingRepeats',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }
}
