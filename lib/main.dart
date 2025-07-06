import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:game_timer/FancyTimerPage.dart';

/// 서비스 진입점 (꼭 최상위 함수로, @pragma 어노테이션 필요)
@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  // 공통으로 사용할 플레이어 인스턴스 생성
  final player = AudioPlayer()
    ..setPlayerMode(PlayerMode.mediaPlayer)
    ..setReleaseMode(ReleaseMode.stop);

  await player.setAudioContext(AudioContext(
    iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.mixWithOthers}),
    android: null, // Android 쪽은 이미 mediaPlayer 모드로 설정되어 있으므로 null 로 둬도 됩니다.
  ));

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Fancy Timer",
      content: "타이머 실행 중...",
    );
  }

  // play 이벤트: 같은 player로 재생
  service.on('play').listen((event) async {
    final data = event as Map<String, dynamic>;
    final String mp3 = data['mp3'];
    final int duration = data['duration'];
    // duration = 100;
    if (mp3.startsWith('sounds/')) {
      await player.play(AssetSource(mp3));
    } else {
      await player.play(DeviceFileSource(mp3));
    }

    // duration 후 자동 정지
    Future.delayed(Duration(seconds: duration), () {
      player.stop();
    });
  });

  // stopAlarm 이벤트: 즉시 정지
  service.on('stopAlarm').listen((_) async {
    await player.stop();
  });

  // 서비스 종료
  service.on('stopService').listen((_) {
    player.stop();
    service.stopSelf();
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart, // ServiceInstance 진입점
      autoStart: true,
      isForegroundMode: true,
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart, // 포그라운드일 때도 onStart 호출
      onBackground: (service) {
        onStart(service);
        return true;
      }, // 백그라운드 진입시에도 onStart
    ),
  );

  // 서비스 시작
  service.startService();

  runApp(const MyApp());
}

const Color appColor = Color(0xFFB14FFF);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: appColor),
        useMaterial3: true,
      ),
      home: const FancyTimerPage(),
    );
  }
}
