import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
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
  // void _startTimer() {
  //   final interval = _pickedDuration.inSeconds;
  //   if (interval <= 0) return;
  //   if (_isRepeating && !_isUnlimited) {
  //     final count = int.tryParse(_repeatCountController.text) ?? 0;
  //     _remainingRepeats = count > 0 ? count : 0;
  //     if (_remainingRepeats == 0) return;
  //   }
  //   _timer?.cancel();
  //   setState(() => _remaining = interval);
  //   _timer = Timer.periodic(Duration(seconds: 1), (t) async {
  //     final next = _remaining - 1;
  //     if (next <= 0) {
  //       await _playAlarmOnce();
  //       if (_isRepeating) {
  //         if (_isUnlimited)
  //           setState(() => _remaining = interval);
  //         else {
  //           _remainingRepeats--;
  //           if (_remainingRepeats > 0)
  //             setState(() => _remaining = interval);
  //           else {
  //             t.cancel();
  //             setState(() => _remaining = 0);
  //           }
  //         }
  //       } else {
  //         t.cancel();
  //         setState(() => _remaining = 0);
  //       }
  //     } else
  //       setState(() => _remaining = next);
  //   });
  // }

  void _startTimer() {
    final totalSec = _pickedDuration.inSeconds;
    if (totalSec <= 0) return;

    // 1) 기존 타이머 취소 & UI 초기화
    _timer?.cancel();
    setState(() => _remaining = totalSec);

    // 2) 1초마다 카운트다운
    _timer = Timer.periodic(Duration(seconds: 1), (t) {
      final next = _remaining - 1;
      if (next <= 0) {
        // 2-1) 0초 도달 시
        t.cancel();
        setState(() => _remaining = 0);

        // 2-2) 여기에 백그라운드 서비스 호출
        final playDuration = int.tryParse(_soundDurationController.text) ?? 3;
        FlutterBackgroundService().invoke('play', {
          'mp3': _selectedMp3,
          'duration': playDuration,
        });
      } else {
        // 2-3) 아직 > 0일 때 UI 업데이트
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
    final colorScheme = Theme.of(context).colorScheme;
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(_pickedDuration.inHours),
        m = two(_pickedDuration.inMinutes.remainder(60)),
        s = two(_pickedDuration.inSeconds.remainder(60));
    final playThreshold = int.tryParse(_soundDurationController.text) ?? 3;

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 타이머 선택부
                    Text('🔔 타이머 설정',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showDurationPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: colorScheme.primary, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$h:$m:$s',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 사운드 선택부
                    Text('🎵 알람 사운드',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedMp3,
                      decoration: InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      items: _playList.map((path) {
                        final label = path.split('/').last;
                        return DropdownMenuItem(
                            value: path, child: Text(label));
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedMp3 = v!),
                    ),

                    const SizedBox(height: 24),

                    // 녹음 토글
                    OutlinedButton.icon(
                      icon: Icon(_isRecordingNow ? Icons.stop : Icons.mic,
                          color: colorScheme.primary),
                      label: Text(_isRecordingNow ? '녹음 중지' : '새로 녹음',
                          style: TextStyle(color: colorScheme.primary)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colorScheme.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _toggleRecording,
                    ),

                    const SizedBox(height: 24),

                    // 재생 시간
                    Text('⏱️ 재생 시간 (초)',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _soundDurationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '예: 3',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 실행 / 중지 버튼
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(Icons.play_arrow),
                          label: Text('실행'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _startTimer,
                        ),
                        OutlinedButton.icon(
                          icon: Icon(Icons.stop),
                          label: Text('중지'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _stopTimer,
                        ),
                      ],
                    ),

                    // 남은 시간 표시 (부드러운 전환)
                    const SizedBox(height: 20),
                    if (_remaining > 0)
                      TweenAnimationBuilder<double>(
                        // 남은 시간이 임팩트 구간(<= playThreshold)이면 1.2배 → 1.0배를 반복
                        tween: Tween(
                            begin: 1.0,
                            end: _remaining <= playThreshold ? 1.2 : 1.0),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        builder: (context, scale, child) => Transform.scale(
                          scale: scale,
                          child: child,
                        ),
                        onEnd: () {
                          // 임팩트 구간일 때만 계속 애니메이션 루프
                          if (_remaining <= playThreshold) setState(() {});
                        },
                        child: Text(
                          '남은 시간: $_remaining 초',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            // 임팩트 구간이면 빨간색, 아니면 기본
                            color: _remaining <= playThreshold
                                ? colorScheme.error
                                : colorScheme.onSurface,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
