import 'dart:convert';
import 'package:felamo/screen/quiz_history.dart';
import 'package:felamo/screen/quez.dart';
import 'package:felamo/screen/video.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../baseurl/baseurl.dart';

class AntasPage extends StatefulWidget {
  final int id;
  final int aralinId;
  final String sessionId;
  final int antasId;

  const AntasPage({
    Key? key,
    required this.id,
    required this.aralinId,
    required this.sessionId,
    required this.antasId,
  }) : super(key: key);

  @override
  State<AntasPage> createState() => _AntasPageState();
}

class _AntasPageState extends State<AntasPage> {
  List<Map<String, dynamic>> lessons = [];
  int? selectedLessonIndex;
  int? completedLessonIndex = 0;

  bool? _quizCompleted;
  bool _quizCheckDone = false;

  @override
  void initState() {
    super.initState();
    fetchLessons();
    // We don't call _checkQuizCompletion() here anymore; fetchLessons() will call it once data is loaded.
  }

  // ── FIX 1: Create a dynamic getter for the currently selected Aralin ID ──
  int get _currentAralinId {
    if (lessons.isEmpty) return widget.aralinId;
    return int.tryParse(lessons[selectedLessonIndex ?? 0]['id'].toString()) ?? widget.aralinId;
  }

  // ── Check whether THIS currently selected aralin's quiz has been passed ──
  Future<void> _checkQuizCompletion() async {
    final targetAralinId = _currentAralinId; // Use the dynamic ID
    
    if (targetAralinId <= 0) {
      if (mounted) setState(() => _quizCheckDone = true);
      return;
    }

    final url = Uri.parse('${baseUrl}get-quiz-history.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': widget.sessionId,
          'aralin_id': targetAralinId, // FIX 2: Send the specific Aralin ID
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _quizCompleted = data['status'] == 'success';
            _quizCheckDone = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _quizCompleted = false;
            _quizCheckDone = true;
          });
        }
      }
    } catch (e) {
      print('Quiz completion check error: $e');
      if (mounted) {
        setState(() {
          _quizCompleted = false;
          _quizCheckDone = true;
        });
      }
    }
  }

  // ── Navigate to quiz or history ───────────────────────────────────────────
  void _onQuizCardTapped() {
    if (_quizCompleted == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizHistoryScreen(
            sessionId: widget.sessionId,
            aralinId: _currentAralinId, // FIX 3: Pass specific Aralin ID
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizScreen(
            antasId: widget.antasId,
            sessionId: widget.sessionId,
            aralinId: _currentAralinId, // FIX 4: Pass specific Aralin ID
          ),
        ),
      ).then((_) {
        _checkQuizCompletion();
      });
    }
  }

  // ── Fetch lessons for this level ──────────────────────────────────────────
  Future<void> fetchLessons() async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}get-aralin.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': widget.sessionId,
          'level_id': widget.antasId,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success' && jsonData['data'] != null) {
          final loaded = List<Map<String, dynamic>>.from(jsonData['data']);
          int targetIndex = 0;
          for (int i = 0; i < loaded.length; i++) {
            if (loaded[i]['id'].toString() == widget.aralinId.toString()) {
              targetIndex = i;
              break;
            }
          }
          setState(() {
            lessons = loaded;
            selectedLessonIndex = targetIndex;
            completedLessonIndex = targetIndex;
          });
          
          // FIX 5: Check quiz status AFTER the lessons are mapped
          _checkQuizCompletion();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
        );
      }
    }
  }

  Color get _quizCardColor {
    if (_quizCompleted == null) return Colors.grey.shade400;
    return _quizCompleted! ? const Color(0xFF388E3C) : const Color(0xFFF57C00);
  }

  IconData get _quizCardIcon {
    if (_quizCompleted == null) return Icons.hourglass_empty;
    return _quizCompleted! ? Icons.history_edu : Icons.quiz;
  }

  String get _quizCardTitle {
    if (_quizCompleted == null) return 'Naghihintay...';
    return _quizCompleted! ? 'Kasaysayan' : 'Pagsusulit';
  }

  String get _quizCardSubtitle {
    if (_quizCompleted == null) return 'Sinusuri...';
    return _quizCompleted!
        ? 'Tingnan ang iyong\nmga sagot'
        : 'Magpatakbo ng mga\npagsusulit at exam';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          'Panimulang Antas',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LessonScreen(
                              id: widget.id,
                              aralinId: _currentAralinId, // FIX 6: Use dynamic ID
                              sessionId: widget.sessionId,
                              antasId: widget.antasId,
                              lessonId: _currentAralinId, // FIX 7: Use dynamic ID
                            ),
                          ),
                        ).then((_) => _checkQuizCompletion());
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1976D2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.menu_book,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Modyul',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Manood ng\nBidyong Aralin',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: GestureDetector(
                      onTap: _quizCheckDone ? _onQuizCardTapped : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _quizCardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _quizCardIcon,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _quizCardTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _quizCardSubtitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_quizCompleted == true) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF388E3C), width: 1),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.verified, color: Color(0xFF388E3C), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Matagumpay mong natapos ang pagsusulit na ito!',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            const Text(
              'Daloy ng Pag-aaral',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: List.generate(
                  lessons.isNotEmpty ? lessons.length : 1,
                  (index) {
                    final isSelected = selectedLessonIndex == index;
                    final isCompleted = completedLessonIndex == index;

                    return GestureDetector(
                      onTap: () {
                        if (lessons.isNotEmpty && index < lessons.length) {
                          setState(() {
                            selectedLessonIndex = index;
                            completedLessonIndex = index;
                            _quizCheckDone = false; // Set to loading state
                            _quizCompleted = null;  // Clear current status
                          });
                          
                          // FIX 8: Check completion again for the NEW selected aralin
                          _checkQuizCompletion();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: EdgeInsets.only(
                          bottom: index <
                                  (lessons.isNotEmpty ? lessons.length - 1 : 0)
                              ? 12
                              : 0,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFD32F2F).withOpacity(0.08)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFD32F2F)
                                : Colors.grey.shade300,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCompleted
                                    ? Icons.check_rounded
                                    : Icons.play_arrow_rounded,
                                color: isCompleted
                                    ? Colors.green[700]
                                    : Colors.grey[600],
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                lessons.isNotEmpty && index < lessons.length
                                    ? lessons[index]['aralin_title'] ?? 'Walang Pamagat'
                                    : 'Aralin ${index + 1}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFFD32F2F)
                                      : Colors.black87,
                                ),
                                overflow: TextOverflow.visible,
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Paksa at Buod ng Aralin',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            lessons.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        final lessonIndex = selectedLessonIndex ?? 0;
                        if (lessonIndex < lessons.length) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LessonScreen(
                                id: widget.id,
                                aralinId: _currentAralinId, // FIX 9: Use dynamic ID
                                sessionId: widget.sessionId,
                                antasId: widget.antasId,
                                lessonId: _currentAralinId, // FIX 10: Use dynamic ID
                              ),
                            ),
                          ).then((_) => _checkQuizCompletion());
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lessons[selectedLessonIndex ?? 0]['aralin_title'] ??
                                'Walang Pamagat',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Buod: ${lessons[selectedLessonIndex ?? 0]['summary'] ?? 'Walang buod.'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...?lessons[selectedLessonIndex ?? 0]['details']
                                  ?.split('\n')
                                  ?.map(
                                    (detail) => Text(
                                      '• $detail',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 14),
                                    ),
                                  )
                                  ?.toList() ??
                              [
                                const Text(
                                  '• Walang detalye.',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14),
                                )
                              ],
                        ],
                      ),
                    ),
                  ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}