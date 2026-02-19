import 'package:felamo/screen/antas.dart';
import 'package:felamo/screen/preloader.dart';
import 'package:felamo/screen/settings.dart';
import 'package:felamo/screen/video.dart';
import 'package:felamo/user/login.dart';
import 'package:felamo/user/profile.dart';
import 'package:felamo/user/verification.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false, // Add this line to remove the debug banner
    );
  }
}