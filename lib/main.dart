import 'package:app_settings/app_settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qiu_internar/firebase_options.dart';
import 'package:qiu_internar/service/fcm_service.dart';
import 'package:qiu_internar/service/notification_service.dart';
import 'loginpage.dart';
import 'home/mainscreen.dart'; // Ensure you have this package imported
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> requestExactAlarmPermission() async {
  if (await Permission.scheduleExactAlarm.isDenied) {
    await Permission.scheduleExactAlarm.request();
  }

  if (await Permission.scheduleExactAlarm.isPermanentlyDenied) {
    // Open device settings if the user permanently denied the permission
    AppSettings.openAppSettings();
  }
}
void main() async{
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  tz.initializeTimeZones(); // Ensure this is initialized
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(MyApp());
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<StatefulWidget> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  NotificationService notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    requestExactAlarmPermission();
    // Get the context after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize notification services
      notificationService.initializeNotificationServices(context);

      // Initialize Firebase messaging
      notificationService.firebaseInit(context);
    });
    initialization();
  }

  void initialization() async {
    await Future.delayed(const Duration(seconds: 2));
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent)
    );
    return MaterialApp(
      title: 'QIU InternAR',
      theme: ThemeData(primaryColor: Colors.blue),
      home: const AuthWrapper(), // Start with the login page
    );
  }
}

class AuthWrapper extends StatelessWidget{
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context){
    //Check if user is logged in
    User? user = FirebaseAuth.instance.currentUser;

    if(user != null){
      return MainScreen();
    }else{
      return LoginPage();
    }

  }
}

