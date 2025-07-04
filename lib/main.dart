import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:game_timer/ttest.dart';

/// 서비스 진입점 (꼭 최상위 함수로, @pragma 어노테이션 필요)
@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  // Android 포그라운드 알림 설정
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Fancy Timer",
      content: "타이머 실행 중...",
    );
  }

  // 'play' 이벤트 리스너
  service.on('play').listen((event) async {
    final data = event as Map<String, dynamic>;
    final String mp3 = data['mp3'];
    final int duration = data['duration'];

    final player = AudioPlayer();
    // assets라면 AssetSource, 로컬파일이면 DeviceFileSource
    if (mp3.startsWith('sounds/')) {
      await player.play(AssetSource(mp3));
    } else {
      await player.play(DeviceFileSource(mp3));
    }
    // 지정된 시간 후 정지
    Future.delayed(Duration(seconds: duration), () => player.stop());
  });

  // 'stopService' 이벤트로 서비스 종료
  service.on('stopService').listen((_) {
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: FancyTimerPage(),
    );
  }
}
