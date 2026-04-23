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

  // --- NEW: tracks whether the quiz for this aralin has been passed ---
  bool _quizCompleted = false;
  bool _quizCheckDone = false;

  @override
  void initState() {
    super.initState();
    print(
        'AntasPage loaded with id: ${widget.id}, aralinId: ${widget.aralinId}, '
        'sessionId: ${widget.sessionId}, antasId: ${widget.antasId}');
    fetchLessons();
    _checkQuizCompletion();
  }

  // ── Quiz completion check ────────────────────────────────────────────────
  Future<void> _checkQuizCompletion() async {
    final url = Uri.parse('${baseUrl}get-quiz-history.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': widget.sessionId,
          'aralin_id': widget.aralinId,
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
        if (mounted) setState(() => _quizCheckDone = true);
      }
    } catch (e) {
      print('Quiz completion check error: $e');
      if (mounted) setState(() => _quizCheckDone = true);
    }
  }

  // ── Fetch lessons ────────────────────────────────────────────────────────
  Future<void> fetchLessons() async {
    final url = Uri.parse('${baseUrl}get-aralin.php');
    print(
        'Fetching lessons for antasId: ${widget.antasId}, sessionId: ${widget.sessionId}');
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

            // Auto-select the aralin that was clicked from the Dashboard
            if (lessons.isNotEmpty) {
              for (int i = 0; i < lessons.length; i++) {
                if (lessons[i]['id'].toString() ==
                    widget.aralinId.toString()) {
                  selectedLessonIndex = i;
                  completedLessonIndex = i;
                  break;
                }
              }
            }

            if (completedLessonIndex != null &&
                completedLessonIndex! >= lessons.length) {
              completedLessonIndex = lessons.isNotEmpty ? 0 : null;
            }
          });
          print(
              'Lessons fetched: ${lessons.length} lessons. Selected index: $selectedLessonIndex');
        } else {
          print('Fetch lessons failed: ${jsonData['message'] ?? 'No message'}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Failed to fetch lessons: ${jsonData['message'] ?? 'Unknown error'}')),
            );
          }
        }
      } else {
        print('Fetch lessons failed with status: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Server error: HTTP ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      print('Fetch lessons error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
        );
      }
    }
  }

  // ── Navigate to quiz OR history depending on completion state ────────────
  void _onQuizCardTapped() {
    if (_quizCompleted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizHistoryScreen(
            sessionId: widget.sessionId,
            aralinId: widget.aralinId,
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
            aralinId: widget.aralinId,
          ),
        ),
      ).then((_) {
        // Re-check after returning in case they just passed
        _checkQuizCompletion();
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
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
            onPressed: () {
              Navigator.pop(context);
              print('Back button pressed, navigating back');
            },
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
            // ── Top action cards ─────────────────────────────────────────
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
                  // Video / Module card
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LessonScreen(
                              id: widget.id,
                              aralinId: widget.aralinId,
                              sessionId: widget.sessionId,
                              antasId: widget.antasId,
                              lessonId: lessons.isNotEmpty
                                  ? lessons[selectedLessonIndex ?? 0]['id']
                                  : 0,
                            ),
                          ),
                        );
                        print(
                            'Navigating to LessonScreen for lesson index: ${selectedLessonIndex ?? 0}');
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
                              style: TextStyle(
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

                  const SizedBox(width: 12),

                  // Quiz / History card — dynamic based on _quizCompleted
                  Expanded(
                    child: GestureDetector(
                      onTap: _quizCheckDone ? _onQuizCardTapped : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: !_quizCheckDone
                              ? Colors.grey.shade400
                              : _quizCompleted
                                  ? const Color(0xFF388E3C)
                                  : const Color(0xFFF57C00),
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
                                !_quizCheckDone
                                    ? Icons.hourglass_empty
                                    : _quizCompleted
                                        ? Icons.history_edu
                                        : Icons.quiz,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              !_quizCheckDone
                                  ? 'Naghihintay...'
                                  : _quizCompleted
                                      ? 'Kasaysayan'
                                      : 'Pagsusulit',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              !_quizCheckDone
                                  ? 'Sinusuri...'
                                  : _quizCompleted
                                      ? 'Tingnan ang iyong\nmga sagot'
                                      : 'Magpatakbo ng mga\npagsusulit at exam',
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

            // ── Completion badge (shown when quiz is done) ───────────────
            if (_quizCompleted) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

            // ── Progress section ─────────────────────────────────────────
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
                    bool isSelected = selectedLessonIndex == index;
                    bool isCompleted = completedLessonIndex == index;

                    return GestureDetector(
                      onTap: () {
                        if (lessons.isNotEmpty && index < lessons.length) {
                          setState(() {
                            selectedLessonIndex = index;
                            completedLessonIndex = index;
                            print('Aralin ${index + 1} selected');
                          });
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: EdgeInsets.only(
                            bottom: index <
                                    (lessons.isNotEmpty
                                        ? lessons.length - 1
                                        : 0)
                                ? 12
                                : 0),
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
                                    ? lessons[index]['title'] ??
                                        'Walang Pamagat'
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

            // ── Lesson summary section ───────────────────────────────────
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
                              builder: (context) => LessonScreen(
                                id: widget.id,
                                aralinId: widget.aralinId,
                                sessionId: widget.sessionId,
                                antasId: widget.antasId,
                                lessonId: lessons[lessonIndex]['id'] ?? 0,
                              ),
                            ),
                          );
                          print(
                              'Navigating to LessonScreen for lesson index: $lessonIndex, '
                              'lessonId: ${lessons[lessonIndex]['id']}');
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lessons[selectedLessonIndex ?? 0]['title'] ??
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
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
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