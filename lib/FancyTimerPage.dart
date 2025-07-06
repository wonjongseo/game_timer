import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:game_timer/admob/global_banner_admob.dart';
import 'package:game_timer/widgets/custom_button.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class FancyTimerPage extends StatefulWidget {
  const FancyTimerPage({super.key});

  @override
  _FancyTimerPageState createState() => _FancyTimerPageState();
}

class _FancyTimerPageState extends State<FancyTimerPage> {
  bool _isAlarmPlaying = false; // 추가
  // 1) assets MP3 목록 (삭제 불가)
  final List<String> _mp3Names = [
    "sounds/police-siren-1.mp3",
    "sounds/police-siren-2.mp3",
    "sounds/police-siren-3.mp3",
  ];
  // 2) 전체 재생 목록 (assets + 녹음 파일)
  List<String> _playList = [];
  String _selectedMp3 = "";

  // 녹음기
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecordingNow = false;
  String? _tempPath;

  // 타이머
  Duration _pickedDuration = const Duration(seconds: 10);
  Timer? _timer;
  int _remaining = 0;

  // 반복 옵션
  bool _isRepeating = false;
  bool _isUnlimited = true;
  final TextEditingController _repeatCountController =
      TextEditingController(text: '2');
  int _remainingRepeats = 0;

  // 사운드 재생 시간
  final TextEditingController _soundDurationController =
      TextEditingController(text: '3');

  // 오디오 플레이어
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _playList = List.from(_mp3Names);
    _loadRecordedFiles();
    _selectedMp3 = _playList.first;
  }

  /// documents 디렉토리의 .m4a 파일을 읽어와 playList에 추가
  Future<void> _loadRecordedFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = Directory(dir.path)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.m4a'))
        .map((f) => f.path)
        .toList();
    setState(() {
      _playList = List.from(_mp3Names)..addAll(files);
      if (!_playList.contains(_selectedMp3)) {
        _selectedMp3 = _playList.first;
      }
    });
  }

  /// 녹음 저장 후 리스트 갱신
  Future<void> _onRecordingStoppedAndSaved(String newPath) async {
    setState(() {
      _playList.add(newPath);
      _selectedMp3 = newPath;
    });
  }

  /// 사용자 녹음 파일만 삭제
  Future<void> _deleteRecording(String path) async {
    try {
      await File(path).delete();
      setState(() {
        _playList.remove(path);
        if (_selectedMp3 == path) {
          _selectedMp3 =
              _playList.isNotEmpty ? _playList.first : _mp3Names.first;
        }
      });
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
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

  // 타이머 Duration 선택
  Future<void> _showDurationPicker() async {
    Duration? result = await showCupertinoModalPopup<Duration>(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: Colors.white,
        child: Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  TextButton(
                    child: Text('1Hour'),
                    onPressed: () =>
                        setState(() => _pickedDuration = Duration(hours: 1)),
                  ),
                  TextButton(
                    child: Text('30Min'),
                    onPressed: () =>
                        setState(() => _pickedDuration = Duration(minutes: 30)),
                  ),
                  TextButton(
                    child: Text('1Min'),
                    onPressed: () =>
                        setState(() => _pickedDuration = Duration(minutes: 1)),
                  ),
                  TextButton(
                    child: Text('30Sec'),
                    onPressed: () =>
                        setState(() => _pickedDuration = Duration(seconds: 30)),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  child: Text('OK'),
                  onPressed: () => Navigator.of(context).pop(_pickedDuration),
                ),
              ),
            ],
          ),
          Expanded(
            child: CupertinoTimerPicker(
              mode: CupertinoTimerPickerMode.hms,
              initialTimerDuration: _pickedDuration,
              onTimerDurationChanged: (val) =>
                  setState(() => _pickedDuration = val),
            ),
          ),
        ]),
      ),
    );
    if (result != null) setState(() => _pickedDuration = result);
  }

  // 녹음 시작/중지 & 파일명 저장 팝업
  Future<void> _toggleRecording() async {
    if (_isRecordingNow) {
      final path = await _recorder.stop();
      setState(() => _isRecordingNow = false);
      if (path != null) {
        _tempPath = path;
        await _showRenameDialog();
      }
    } else {
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

  // 파일명 다이얼로그
  Future<void> _showRenameDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Enter filename'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Enter name without extension'),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
              _tempPath = null;
            },
          ),
          TextButton(
            child: Text('Save'),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty && _tempPath != null) {
                final dir = File(_tempPath!).parent;
                final newPath = '${dir.path}/$name.m4a';
                await File(_tempPath!).rename(newPath);
                await _onRecordingStoppedAndSaved(newPath);
              }
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // 타이머 시작
  void _startTimer() {
    final total = _pickedDuration.inSeconds;
    setState(() => _isAlarmPlaying = true);
    if (total <= 0) return;
    if (_isRepeating && !_isUnlimited) {
      _remainingRepeats = int.tryParse(_repeatCountController.text) ?? 0;
      if (_remainingRepeats <= 0) return;
    }
    _runCountdown(total);
  }

  void _runCountdown(int total) {
    _timer?.cancel();
    setState(() => _remaining = total);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final next = _remaining - 1;
      if (next <= 0) {
        t.cancel();
        setState(() => _remaining = 0);
        FlutterBackgroundService().invoke('play', {
          'mp3': _selectedMp3,
          'duration': int.tryParse(_soundDurationController.text) ?? 3,
        });
        if (_isRepeating) {
          if (_isUnlimited) {
            Future.delayed(
                const Duration(seconds: 1), () => _runCountdown(total));
          } else if (_remainingRepeats-- > 1) {
            Future.delayed(
                const Duration(seconds: 1), () => _runCountdown(total));
          }
        }
      } else {
        setState(() => _remaining = next);
      }
    });
  }

  void _stopTimer() {
    // 1) 메인 타이머/플레이어 정지
    _timer?.cancel();
    _audioPlayer.stop();
    setState(() => _isAlarmPlaying = false); // 추가

    // 2) 백그라운드 서비스에 “정지” 신호 보내기
    FlutterBackgroundService().invoke('stopAlarm');

    // 3) UI 상태 초기화
    setState(() {
      _remaining = 0;
      _remainingRepeats = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(_pickedDuration.inHours),
        m = two(_pickedDuration.inMinutes.remainder(60)),
        s = two(_pickedDuration.inSeconds.remainder(60));
    final playThreshold = int.tryParse(_soundDurationController.text) ?? 3;

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 타이머 설정
                        const Text('🔔 Timer Settings',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _showDurationPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: cs.primary, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$h:$m:$s',
                              style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 사운드 선택 + 삭제 버튼
                        const Text('🎵 Alarm Sound',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedMp3,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                items: _playList.map((path) {
                                  final label = path.split('/').last;
                                  return DropdownMenuItem(
                                      value: path, child: Text(label));
                                }).toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedMp3 = v!),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!_mp3Names.contains(_selectedMp3))
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Delete this recording',
                                onPressed: () => _deleteRecording(_selectedMp3),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        CustomButton(
                          label: _isRecordingNow
                              ? 'Stop Record(Save)'
                              : 'New Record',
                          onTap: _toggleRecording,
                        ),
                        const SizedBox(height: 24),

                        // 반복 옵션
                        CheckboxListTile(
                          title: const Text('Repeat'),
                          value: _isRepeating,
                          onChanged: (v) => setState(() => _isRepeating = v!),
                        ),
                        if (_isRepeating) ...[
                          SizedBox(
                            height: 100,
                            child: Column(children: [
                              Expanded(
                                child: RadioListTile<bool>(
                                  title: const Text('Unlimited'),
                                  value: true,
                                  groupValue: _isUnlimited,
                                  onChanged: (v) =>
                                      setState(() => _isUnlimited = v!),
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<bool>(
                                  title: const Text('Specify Count'),
                                  value: false,
                                  groupValue: _isUnlimited,
                                  onChanged: (v) =>
                                      setState(() => _isUnlimited = v!),
                                ),
                              ),
                            ]),
                          ),
                          if (!_isUnlimited)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: TextField(
                                controller: _repeatCountController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Repeat count'),
                              ),
                            ),
                        ],
                        const SizedBox(height: 24),

                        // 재생 시간
                        const Text('⏱️ Play Duration (sec)',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _soundDurationController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Ex) 3',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // 실행 / 중지 버튼
                      ],
                    ),
                  ),
                ),
              ),
              // 남은 시간 중앙 표시
              if (_remaining > 0)
                Align(
                  alignment: Alignment.center,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                        begin: 1.0,
                        end: _remaining <= playThreshold ? 1.2 : 1.0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                    builder: (ctx, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    onEnd: () {
                      if (_remaining <= playThreshold) setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Remaining time: $_remaining s',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _remaining <= playThreshold
                              ? cs.error
                              : cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlobalBannerAdmob(),
            _isAlarmPlaying
                ? CustomButton(
                    label: "Stop",
                    onTap: _stopTimer,
                    verticalPadding: 12,
                  )
                : CustomButton(
                    label: "Start",
                    onTap: _startTimer,
                    verticalPadding: 12,
                  )
          ],
        ),
      )),
    );
  }
}
