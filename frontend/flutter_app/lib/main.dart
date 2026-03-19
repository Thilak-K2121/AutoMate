import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const AutoMateApp());
}

class AutoMateApp extends StatelessWidget {
  const AutoMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Inter', // Or whichever font you prefer
      ),
      home: const SplashScreenPage(),
    );
  }
}