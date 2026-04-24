import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import '../baseurl/baseurl.dart';
import 'package:felamo/screen/quez.dart';

class LessonScreen extends StatefulWidget {
  final int id;
  final int aralinId;
  final String sessionId;
  final int antasId; 
  final int lessonId;

  const LessonScreen({
    Key? key,
    required this.id,
    required this.sessionId,
    required this.antasId,
    required this.aralinId, 
    required this.lessonId, 
  }) : super(key: key);

  @override
  _LessonScreenState createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool isVideoInitialized = false;
  bool isVideoCompleted = false;
  List<Map<String, dynamic>> lessons = [];
  int currentPlayingIndex = 0;
  List<bool> videoCompletionStatus = [];
  bool allVideosCompleted = false;
  Duration? lastPosition;
  bool isFullScreen = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    print('LessonScreen Initialized: id=${widget.id}, aralinId=${widget.aralinId}, sessionId=${widget.sessionId}, antasId=${widget.antasId}');
    fetchLesson();
    _animationController.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _animationController.dispose();
    print('Video controller and animation disposed');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && isVideoInitialized && _controller != null) {
      lastPosition = _controller!.value.position;
      _controller!.pause();
      print('App paused, video position saved: $lastPosition');
    } else if (state == AppLifecycleState.resumed && isVideoInitialized && _controller != null) {
      _controller!.seekTo(lastPosition ?? Duration.zero);
      print('App resumed, seeking to: $lastPosition');
    }
  }

  Future<void> fetchLesson() async {
    final url = Uri.parse('${baseUrl}get-aralin.php');
    print('Fetching lessons for antasId: ${widget.antasId}, sessionId: ${widget.sessionId}');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': widget.sessionId,
          'level_id': widget.antasId,
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success' && jsonData['data'] != null) {
          setState(() {
            lessons = List<Map<String, dynamic>>.from(jsonData['data']);
            videoCompletionStatus = List.generate(lessons.length, (_) => false);
          });
          print('Lessons fetched: ${lessons.length} lessons');
          if (lessons.isNotEmpty) {
            // Find the index of the video the user actually clicked
            int targetIndex = 0;
            for (int i = 0; i < lessons.length; i++) {
              if (lessons[i]['id'].toString() == widget.lessonId.toString()) {
                targetIndex = i;
                break;
              }
            }
            // Play that specific video instead of 0
            initializeVideo(targetIndex); 
          } else {
            print('No lessons found');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('No lessons available', style: GoogleFonts.poppins(fontSize: 14)),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        } else {
          print('Fetch lesson failed: ${jsonData['message'] ?? 'No message'}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to fetch lessons: ${jsonData['message'] ?? 'Unknown error'}',
                    style: GoogleFonts.poppins(fontSize: 14)),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        print('Fetch lesson failed with status: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Server error: HTTP ${response.statusCode}', style: GoogleFonts.poppins(fontSize: 14)),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print('Fetch lesson error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e', style: GoogleFonts.poppins(fontSize: 14)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void initializeVideo(int index) {
    if (index >= lessons.length || index < 0) {
      print('Invalid video index: $index, lessons length: ${lessons.length}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid video index', style: GoogleFonts.poppins(fontSize: 14)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final lesson = lessons[index];
    if (lesson['attachment_filename'] == null) {
      print('Missing attachment_filename for lesson index: $index');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video file not found', style: GoogleFonts.poppins(fontSize: 14)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    String videoUrl =
        '${storageUrl}videos/${lesson['attachment_filename']}';
    print('Initializing video: $videoUrl');
    currentPlayingIndex = index;

    if (_controller != null && isVideoInitialized) {
      _controller!.dispose();
      print('Previous video controller disposed');
    }

    _controller = VideoPlayerController.network(videoUrl)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            isVideoInitialized = true;
            isVideoCompleted = false;
          });
          print('Video initialized: $videoUrl');
          if (lastPosition != null) {
            _controller!.seekTo(lastPosition!);
            print('Seeking to last position: $lastPosition');
          }
          _controller!.play();
          _controller!.addListener(() {
            if (_controller!.value.isInitialized) {
              final isEnded = _controller!.value.position >= _controller!.value.duration;
              if (isEnded && !videoCompletionStatus[index]) {
                print('Video $index completed at position: ${_controller!.value.position}');
                _showCompletionDialog(index);
              }
            }
          });
        }
      }).catchError((error) {
        print('Video init error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load video: $error', style: GoogleFonts.poppins(fontSize: 14)),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
  }

  Future<void> _showCompletionDialog(int index) async {
    if (index >= lessons.length || index < 0) return;

    setState(() {
      videoCompletionStatus[index] = true;
      isVideoCompleted = true;
    });

    final doneUrl = Uri.parse('${baseUrl}insert-done-aralin.php');

    try {
      final response = await http.post(
        doneUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': widget.sessionId,
          'aralin_id':  lessons[index]['id'],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool firstWatch     = data['first_watch']     ?? false;
        final int  pointsReceived = data['points_received'] ?? 0;

        String titleMessage;
        Widget? rewardImage;

        if (data['status'] == 'success' && firstWatch) {
          // First time — show halo-halo reward
          titleMessage = '🎉 Nakakuha ka ng Halo-halo!';
          rewardImage  = Image.asset('assets/halohalo.png', height: 100);
        } else {
          // Re-watch — quiz is unlocked again, no bonus
          titleMessage = 'Tapos na ang Re-watch!';
        }

        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(titleMessage,
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (rewardImage != null) ...[rewardImage, const SizedBox(height: 10)],
                  Text(
                    firstWatch
                        ? 'Nakatanggap ka ng $pointsReceived puntos!\nNaka-unlock na ang pagsusulit.'
                        : 'Naka-unlock na muli ang pagsusulit. Subukang muli!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 15),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('OK', style: GoogleFonts.poppins(color: Colors.blue)),
                ),
              ],
            ),
          );

          // // Offer to go to the next video or the quiz
          // if (index + 1 < lessons.length) {
          //   _offerNextVideo(index);
          // } else {
          //   setState(() => allVideosCompleted = true);
          // }
        }
      }
    } catch (e) {
      print('Error in _showCompletionDialog: $e');
    }
  }

  void toggleFullScreen() {
    setState(() {
      isFullScreen = !isFullScreen;
      print('Full screen toggled: $isFullScreen');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFD4A574),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              print('Back button pressed, navigating back');
            },
          ),
        ),
        title: Text(
          'Bidyo ng Aralin',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F5F5), Color(0xFFE0E0E0)],
          ),
        ),
        child: lessons.isEmpty
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)))
            : FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isFullScreen && isVideoInitialized && _controller != null)
                        GestureDetector(
                          onTap: toggleFullScreen,
                          child: Container(
                            width: double.infinity,
                            color: Colors.black,
                            child: AspectRatio(
                              aspectRatio: _controller!.value.aspectRatio,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  VideoPlayer(_controller!),
                                  Positioned(
                                    bottom: 16,
                                    right: 16,
                                    child: IconButton(
                                      icon: Icon(Icons.fullscreen_exit, color: Colors.white.withOpacity(0.8), size: 32),
                                      onPressed: toggleFullScreen,
                                    ),
                                  ),
                                  if (!_controller!.value.isPlaying)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _controller!.play();
                                          print('Video playing');
                                        });
                                      },
                                      child: Icon(Icons.play_circle_filled, size: 80, color: Colors.white.withOpacity(0.8)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (currentPlayingIndex < lessons.length && isVideoInitialized && _controller != null)
                        GestureDetector(
                          onTap: toggleFullScreen,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AspectRatio(
                                aspectRatio: _controller!.value.aspectRatio,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    VideoPlayer(_controller!),
                                    Positioned(
                                      bottom: 16,
                                      right: 16,
                                      child: IconButton(
                                        icon: Icon(Icons.fullscreen, color: Colors.white.withOpacity(0.8), size: 32),
                                        onPressed: toggleFullScreen,
                                      ),
                                    ),
                                    if (!_controller!.value.isPlaying)
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _controller!.play();
                                            print('Video playing');
                                          });
                                        },
                                        child: Icon(Icons.play_circle_filled, size: 80, color: Colors.white.withOpacity(0.8)),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.lock_outline, color: Colors.white, size: 40),
                          ),
                        ),
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lessons.isNotEmpty && currentPlayingIndex < lessons.length
                                  ? lessons[currentPlayingIndex]['aralin_title'] ?? 'Walang Pamagat'
                                  : 'Walang Pamagat',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mga Layunin sa Pagkatuto',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0D47A1),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('• ', style: TextStyle(color: Color(0xFF0D47A1), fontSize: 16)),
                                      Expanded(
                                        child: Text(
                                          lessons.isNotEmpty && currentPlayingIndex < lessons.length
                                              ? lessons[currentPlayingIndex]['details'] ?? 'Walang detalye.'
                                              : 'Walang detalye.',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            height: 1.5,
                                            color: const Color(0xFF0D47A1),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF8A65), Color(0xFFF4511E)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.3),
                                    spreadRadius: 2,
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: const Icon(Icons.star, color: Colors.white, size: 30),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Makakuha ng Halo-halo!',
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          lessons.length > 1
                                              ? 'Kumpletuhin ang bawat bidyong aralin upang makakuha ng 50 puntos.'
                                              : 'Kumpletuhin ang bidyong aralin upang makakuha ng 100 puntos.',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.white,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // NEW QUIZ BUTTON - Only shows if videos are done!
                      if (allVideosCompleted)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.only(bottom: 24),
                          child: ElevatedButton(
                            onPressed: () {
                              _controller?.pause();
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => QuizScreen(
                                    antasId: widget.antasId,
                                    sessionId: widget.sessionId,
                                    aralinId: widget.aralinId,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                            child: Text(
                              'Pumunta sa Pagsusulit',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        
                    ],
                  ),
                ),
              ),
      ),
      floatingActionButton: isVideoInitialized && !isFullScreen && _controller != null
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                    print('Video paused');
                  } else {
                    _controller!.play();
                    print('Video playing');
                  }
                });
              },
              backgroundColor: const Color(0xFFB71C1C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Icon(
                _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            )
          : null,
    );
  }
}