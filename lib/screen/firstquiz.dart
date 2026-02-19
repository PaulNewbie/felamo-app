import 'dart:convert';
import 'package:felamo/baseurl/baseurl.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class Firstquiz extends StatefulWidget {
  const Firstquiz({super.key});

  @override
  State<Firstquiz> createState() => _FirstquizState();
}

class _FirstquizState extends State<Firstquiz> {
  late VideoPlayerController _controller;
  bool isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    fetchVideo();
  }

  Future<void> fetchVideo() async {
    final response = await http.post(
      Uri.parse('${baseUrl}/get-aralin.php'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "session_id": "ef25989f01946d0723b1abf43cf305ba8537952adcb93911431640bf0df87fef",
        "level_id": "1"
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success' && data['data'].isNotEmpty) {
        final filename = data['data'][0]['attachment_filename'];
        final videoUrl = '${baseUrl}/storage/videos/$filename';

        _controller = VideoPlayerController.network(videoUrl)
          ..initialize().then((_) {
            setState(() {
              isVideoInitialized = true;
              _controller.setLooping(true);
              _controller.play();
            });
          });
      }
    } else {
      print("Failed to load video");
    }
  }

  @override
  void dispose() {
    if (isVideoInitialized) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF800000),
              Colors.white,
              Color(0xFFFFF8DC),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                color: Colors.white,
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isVideoInitialized)
                        AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        )
                      else
                        const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 20),

                      Container(
                        color: const Color(0xFF800000),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Panlimumlang Antas',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Buttons Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6A0DAD),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {},
                              child: Column(
                                children: const [
                                  Icon(Icons.book, color: Colors.white, size: 40),
                                  SizedBox(height: 8),
                                  Text('Moduyl', style: TextStyle(color: Colors.white, fontSize: 16)),
                                  Text('Manood ng Bidyong Aralin',
                                      style: TextStyle(color: Colors.white, fontSize: 12),
                                      textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {},
                              child: Column(
                                children: const [
                                  Icon(Icons.edit, color: Colors.white, size: 40),
                                  SizedBox(height: 8),
                                  Text('Pag-aaruri', style: TextStyle(color: Colors.white, fontSize: 16)),
                                  Text('magasagot ng mga pagsusulit at exam',
                                      style: TextStyle(color: Colors.white, fontSize: 12),
                                      textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Progreso ng Antas',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          Text('Aralin 1: Awtiting Bayan', style: TextStyle(fontSize: 14)),
                          Spacer(),
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: const [
                          Text('Aralin 2: Karunungang-Bayan', style: TextStyle(fontSize: 14)),
                          Spacer(),
                          Icon(Icons.circle, color: Colors.grey, size: 20),
                        ],
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Mga Paksa ng Aralin',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Aralin 1: Mga Awtiting-Bayan sa Panahon ng Katutubo',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            SizedBox(height: 8),
                            Text('• Nakikilala ang mga Pangkat ng mga Katutubo ng Bansa',
                                style: TextStyle(fontSize: 12)),
                            Text('• Nais-isa ang mga Anyo ng Panitik sa Panahon ng Katutubo',
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Aralin 2: Karunungang-Bayan',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            SizedBox(height: 8),
                            Text('• Mga Uri ng Karunungang-Bayan', style: TextStyle(fontSize: 12)),
                            Text('• Kahalagahan at Gamit sa Pang-araw-araw na buhay',
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
