import 'dart:async';
import 'package:felamo/user/login.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 4), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Login()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final loaderWidth = screenWidth * 0.7;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8B0000), Color(0xFFFFF3B0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Centered Logo
            Expanded(
              flex: 3,
              child: Center(
                child: Image.asset(
                  'assets/felamologo.png',
                  width: 250,
                ),
              ),
            ),

            // Moving Loader
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Background Track
                        Container(
                          height: 20,
                          width: loaderWidth,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Color(0xFF8B0000), width: 2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),

                        // Red progress fill
                        TweenAnimationBuilder<double>(
                          duration: const Duration(seconds: 4),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Container(
                              height: 20,
                              width: loaderWidth * value,
                              decoration: BoxDecoration(
                                color: Color(0xFF8B0000),
                                borderRadius: BorderRadius.circular(20),
                              ),
                            );
                          },
                        ),

                        // Moving jeepney image at the top
                        // TweenAnimationBuilder<double>(
                        //   duration: const Duration(seconds: 4),
                        //   tween: Tween(begin: 0.0, end: 1.0),
                        //   builder: (context, value, child) {
                        //     return Positioned(
                        //       left: (loaderWidth - 40) * value,
                        //       top: -50, // Positioned above the loading bar
                        //       child: Image.asset(
                        //         'assets/jeepjeep.png',
                        //         width: 40,
                        //         height: 40,
                        //         fit: BoxFit.contain,`
                        //         filterQuality: FilterQuality.high,
                        //       ),
                        //     );
                        //   },
                        // ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Naglo-load...',
                      style: TextStyle(
                        color: Color(0xFF8B0000),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}