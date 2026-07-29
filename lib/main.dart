import 'package:felamo/screen/antas.dart';
import 'package:felamo/screen/preloader.dart';
import 'package:felamo/screen/settings.dart';
import 'package:felamo/screen/video.dart';
import 'package:felamo/user/login.dart';
import 'package:felamo/user/profile.dart';
import 'package:felamo/user/verification.dart';
import 'package:felamo/services/font_scale_controller.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await fontScaleController.load(); // restore saved preference before UI builds
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: fontScaleController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Felamo',
          theme: ThemeData(),
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(fontScaleController.scale),
              ),
              child: child!,
            );
          },
        );
      },
    );
  }
}