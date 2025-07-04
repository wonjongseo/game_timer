// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_background_service_android/flutter_background_service_android.dart';


// Future<void> initalizeService() async {
//   final service = FlutterBackgroundService();
//   await service.configure(
//     iosConfiguration: IosConfiguration(
//       autoStart: true,
//       onForeground: onStart,
//       onBackground: onIosBackground, //ios의 경우 백그라운드시의 function 이 별개로 되어있다.
//     ),
//     androidConfiguration: AndroidConfiguration(
//       onStart: onStart,
//       isForegroundMode: true, //false 시 백그라운드모드
//       autoStart: frue, //초기화 시 자동 시작
//     ),
//   );
// }


// @pragma('vm:entry-point')
// Future<bool> onIosBackground(ServiceInstance service) async {
//   WidgetsFlutterBinding.ensureInitialized();
//   DartPluginRegistrant.ensureInitialized();
//   return true;
// }

// @pragma('vm:entry-point')
// onStart(ServiceInstance service) async {
//   DartPluginRegistrant.ensureInitialized();
//   if (service is AndroidServiceInstance) { // 서비스의 백그라운드/포그라운드가 변경되었을경우
//     service.on('setAsForeground').listen((event) {
//       service.setAsBackgroundService();
//     });
//     service.on('setAsBackground').listen((event) { // 서비스의 백그라운드/포그라운드가 변경되었을경우
//       service.setAsBackgroundService();
//     });
//   }
//   service.on('stopService').listen((event) {
//     service.stopSelf();
//   });
//   Timer.periodic(const Duration(seconds: 1), (timer) async {//매 초 백그라운드 서비스를 실행한다.
//     if (service is AndroidServiceInstance) {
//       if (await service.isForegroundService()) { // foregroundservice의 경우
//       	flutterLocalNotificationsPlugin.show(
//           notificationId,
//           'Service',
//           'Awesome ${DateTime.now()}',
//           const NotificationDetails(
//             android: AndroidNotificationDetails(
//               notificationChannelId,
//               'MY FOREGROUND SERVICE',
//               icon: 'ic_bg_service_small',
//               ongoing: true,
//             ),
//           ),
//         );
//       }
//       // 이 이후의 경우는 사용자가 인지하지 못하는 백그라운드 function들이 실행된다.
//       print("Background");
//       service.invoke('update');
//     }
//   });

// FlutterBackgroundService().startService();//서비스 시작
// FlutterBackgroundService().invoke('setAsForeground');// 서비스를 foreground로 변경
// FlutterBackgroundService().invoke('setAsBackground');// 서비스를 background로 변경
// FlutterBackgroundService().invoke('stopService'); // 서비스 정지