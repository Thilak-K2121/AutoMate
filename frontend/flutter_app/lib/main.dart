import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/api_service.dart';
import 'services/fcm_service.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await FcmService.initialize();
  } catch (e) {
    debugPrint("Firebase init failed: $e");
  }

  runApp(const AutoMateApp());
}

class AutoMateApp extends StatelessWidget {
  const AutoMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: ApiService.navigatorKey,
      title: 'AutoMate',
      debugShowCheckedModeBanner: false,
      // 🎨 Central design system — see lib/theme/app_theme.dart
      theme: AppTheme.light,
      home: const SplashScreenPage(),
    );
  }
}