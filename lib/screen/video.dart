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

class _LessonScreenState extends State<LessonScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
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

  // ── Extra UI state ─────────────────────────────────────────────────────────
  bool _showVideoControls = true;
  bool _isBuffering = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
            int targetIndex = 0;
            for (int i = 0; i < lessons.length; i++) {
              if (lessons[i]['id'].toString() == widget.lessonId.toString()) {
                targetIndex = i;
                break;
              }
            }
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

    String videoUrl = '${storageUrl}videos/${lesson['attachment_filename']}';
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
              // Update buffering state for UI
              if (mounted) {
                final buffering = _controller!.value.isBuffering;
                if (buffering != _isBuffering) {
                  setState(() => _isBuffering = buffering);
                }
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
          titleMessage = '🎉 Nakakuha ka ng Halo-halo!';
          rewardImage  = Image.asset('assets/halohalo.png', height: 100);
        } else {
          titleMessage = 'Tapos na ang Re-watch!';
        }

        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Trophy/reward icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: firstWatch ? const Color(0xFFFFF8E1) : const Color(0xFFE3F2FD),
                        shape: BoxShape.circle,
                      ),
                      child: rewardImage != null
                          ? ClipOval(child: rewardImage)
                          : Icon(
                              Icons.replay_rounded,
                              color: const Color(0xFF1565C0),
                              size: 42,
                            ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      titleMessage,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: firstWatch ? const Color(0xFFFFF8E1) : const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        firstWatch
                            ? 'Nakatanggap ka ng $pointsReceived puntos!\nNaka-unlock na ang pagsusulit.'
                            : 'Naka-unlock na muli ang pagsusulit. Subukang muli!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: firstWatch ? Colors.orange[800] : const Color(0xFF1565C0),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB71C1C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text('OK, Sige!',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
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

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatDuration(Duration duration) {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _videoProgress {
    if (_controller == null || !isVideoInitialized) return 0.0;
    final dur = _controller!.value.duration.inMilliseconds;
    if (dur == 0) return 0.0;
    return (_controller!.value.position.inMilliseconds / dur).clamp(0.0, 1.0);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: lessons.isEmpty
            ? _buildLoadingState()
            : isFullScreen
                ? _buildFullScreenPlayer()
                : _buildNormalLayout(),
      ),
    );
  }

  // ── Loading state ──────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Column(
      children: [
        _buildAppBarArea(),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFFB71C1C), strokeWidth: 2.5),
                const SizedBox(height: 16),
                Text('Naglo-load ng aralin...',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.white54)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Full screen player ─────────────────────────────────────────────────────

  Widget _buildFullScreenPlayer() {
    return GestureDetector(
      onTap: () {
        setState(() => _showVideoControls = !_showVideoControls);
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isVideoInitialized && _controller != null)
              AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),

            // Buffering spinner
            if (_isBuffering)
              const CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),

            // Controls overlay
            if (_showVideoControls) ...[
              // Dark gradient overlay
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCC000000), Colors.transparent, Colors.transparent, Color(0xCC000000)],
                    stops: [0.0, 0.25, 0.75, 1.0],
                  ),
                ),
              ),
              // Top bar
              Positioned(
                top: 40,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    _circleButton(Icons.fullscreen_exit_rounded, toggleFullScreen),
                    const Spacer(),
                    Text(
                      lessons.isNotEmpty ? lessons[currentPlayingIndex]['aralin_title'] ?? '' : '',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              // Center play/pause
              _buildCenterPlayButton(),
              // Bottom bar
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: _buildVideoProgressBar(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Normal (non-fullscreen) layout ─────────────────────────────────────────

  Widget _buildNormalLayout() {
    final lesson = lessons.isNotEmpty && currentPlayingIndex < lessons.length
        ? lessons[currentPlayingIndex]
        : null;
    final title  = lesson?['aralin_title'] ?? 'Walang Pamagat';
    final details = (lesson?['details'] ?? '') as String;

    return Column(
      children: [
        // App bar
        _buildAppBarArea(),

        // ── VIDEO PLAYER ────────────────────────────────────────────────────
        _buildInlineVideoPlayer(),

        // ── SCROLLABLE INFO ─────────────────────────────────────────────────
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF7F3F0),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Title
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Lesson badge row
                  Row(
                    children: [
                      _infoBadge(
                        Icons.menu_book_rounded,
                        'Aralin ${currentPlayingIndex + 1} ng ${lessons.length}',
                        const Color(0xFFB71C1C),
                        const Color(0xFFFFEBEE),
                      ),
                      const SizedBox(width: 8),
                      if (isVideoCompleted)
                        _infoBadge(
                          Icons.check_circle_rounded,
                          'Tapos na',
                          const Color(0xFF2E7D32),
                          const Color(0xFFE8F5E9),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Objectives card
                  if (details.isNotEmpty) _buildObjectivesCard(details),

                  const SizedBox(height: 16),

                  // Reward banner
                  _buildRewardBanner(),

                  // Quiz button — appears as soon as video is done
                  if (isVideoCompleted) ...[
                    const SizedBox(height: 20),
                    _buildGoToQuizButton(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBarArea() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B0000), Color(0xFFB71C1C), Color(0xFFD32F2F)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  print('Back button pressed, navigating back');
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bidyo ng Aralin',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (lessons.isNotEmpty)
                      Text(
                        lessons[currentPlayingIndex]['aralin_title'] ?? '',
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.white.withOpacity(0.72)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Inline video player with custom controls overlay ───────────────────────

  Widget _buildInlineVideoPlayer() {
    return GestureDetector(
      onTap: () {
        if (isVideoInitialized && _controller != null) {
          setState(() {
            if (_controller!.value.isPlaying) {
              _controller!.pause();
            } else {
              _controller!.play();
            }
          });
        } else {
          toggleFullScreen();
        }
      },
      child: Container(
        width: double.infinity,
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: isVideoInitialized && _controller != null
              ? _controller!.value.aspectRatio
              : 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Video or placeholder
              if (isVideoInitialized && _controller != null)
                VideoPlayer(_controller!)
              else
                Container(
                  color: const Color(0xFF1A1A1A),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFFB71C1C), strokeWidth: 2.5),
                      const SizedBox(height: 14),
                      Text('Inihahanda ang bidyo...',
                          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13)),
                    ],
                  ),
                ),

              // Buffering spinner
              if (_isBuffering && isVideoInitialized)
                Container(
                  color: Colors.black38,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
                  ),
                ),

              // Play/pause overlay when paused
              if (isVideoInitialized && _controller != null && !_controller!.value.isPlaying && !_isBuffering)
                Container(
                  color: Colors.black26,
                  child: _buildCenterPlayButton(),
                ),

              // Bottom gradient + progress bar + fullscreen button
              if (isVideoInitialized && _controller != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xDD000000), Colors.transparent],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 20, 12, 10),
                    child: Column(
                      children: [
                        _buildVideoProgressBar(),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // Current / total time
                            ValueListenableBuilder(
                              valueListenable: _controller!,
                              builder: (_, VideoPlayerValue val, __) {
                                return Text(
                                  '${_formatDuration(val.position)}  /  ${_formatDuration(val.duration)}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                            const Spacer(),
                            // Fullscreen button
                            GestureDetector(
                              onTap: toggleFullScreen,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Center play button ─────────────────────────────────────────────────────

  Widget _buildCenterPlayButton() {
    final isPlaying = isVideoInitialized && _controller != null && _controller!.value.isPlaying;
    return GestureDetector(
      onTap: () {
        if (isVideoInitialized && _controller != null) {
          setState(() {
            if (_controller!.value.isPlaying) {
              _controller!.pause();
            } else {
              _controller!.play();
            }
          });
        }
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 34,
        ),
      ),
    );
  }

  // ── Seek bar ───────────────────────────────────────────────────────────────

  Widget _buildVideoProgressBar() {
    if (!isVideoInitialized || _controller == null) return const SizedBox.shrink();

    return ValueListenableBuilder(
      valueListenable: _controller!,
      builder: (_, VideoPlayerValue val, __) {
        final dur = val.duration.inMilliseconds;
        final pos = val.position.inMilliseconds.clamp(0, dur);
        final progress = dur > 0 ? pos / dur : 0.0;

        return SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: const Color(0xFFB71C1C),
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
          ),
          child: Slider(
            value: progress.toDouble(),
            onChanged: (v) {
              final newPos = Duration(milliseconds: (v * dur).toInt());
              _controller!.seekTo(newPos);
            },
          ),
        );
      },
    );
  }

  // ── Lesson objectives card ─────────────────────────────────────────────────

  Widget _buildObjectivesCard(String details) {
    final lines = details.split('\n').where((d) => d.trim().isNotEmpty).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFE3F2FD),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.flag_rounded, color: Color(0xFF1565C0), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Mga Layunin sa Pagkatuto',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: lines.map((line) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1565C0),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          line,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF424242),
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reward banner ──────────────────────────────────────────────────────────

  Widget _buildRewardBanner() {
    final hasMultiple = lessons.length > 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB71C1C).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.emoji_food_beverage_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Makakuha ng Halo-halo!',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasMultiple
                      ? 'Kumpletuhin ang bawat bidyo para makakuha ng 50 puntos.'
                      : 'Kumpletuhin ang bidyo para makakuha ng 100 puntos.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.82),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.7), size: 22),
        ],
      ),
    );
  }

  // ── Go to quiz button ──────────────────────────────────────────────────────

  Widget _buildGoToQuizButton() {
    return GestureDetector(
      onTap: () {
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7D32).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon bubble
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.quiz_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Handa ka na!',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.78),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Pumunta sa Pagsusulit',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ── Small helpers ──────────────────────────────────────────────────────────

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.grey[500],
        letterSpacing: 0.8,
      ),
    );
  }
}