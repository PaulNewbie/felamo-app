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
      backgroundColor: const Color(0xFFF4F6F9),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeroSection()),
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF4F6F9),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_quizCompleted == true) _buildPassBanner(),
                  _buildSectionLabel('Daloy ng pag-aaral'),
                  const SizedBox(height: 10),
                  _buildLessonList(),
                  const SizedBox(height: 22),
                  _buildSectionLabel('Buod ng aralin'),
                  const SizedBox(height: 10),
                  _buildSummaryCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildHeroSection() {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF8B0000), // deep maroon at top-left
          Color(0xFFC62828), // standard red mid
          Color(0xFFE57373), // soft rose at bottom-right
        ],
        stops: [0.0, 0.55, 2.0],
      ),
    ),
    padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Panimulang Antas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildActionCard(
                icon: Icons.menu_book_rounded,
                label: 'Modyul',
                subtitle: 'Manood ng\nbidyong aralin',
                color: const Color(0xFF1565C0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LessonScreen(
                        id: widget.id,
                        aralinId: _currentAralinId,
                        sessionId: widget.sessionId,
                        antasId: widget.antasId,
                        lessonId: _currentAralinId,
                      ),
                    ),
                  ).then((_) => _checkQuizCompletion());
                },
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildQuizActionCard()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 11,
                    height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizActionCard() {
    Color cardColor;
    IconData cardIcon;
    String cardLabel;
    String cardSubtitle;

    if (!_quizCheckDone) {
      cardColor = Colors.white.withOpacity(0.15);
      cardIcon = Icons.hourglass_empty_rounded;
      cardLabel = 'Naghihintay...';
      cardSubtitle = 'Sinusuri ang\npagsusulit';
    } else if (_quizCompleted == true) {
      cardColor = const Color(0xFF2E7D32);
      cardIcon = Icons.history_edu_rounded;
      cardLabel = 'Kasaysayan';
      cardSubtitle = 'Tingnan ang iyong\nmga sagot';
    } else {
      cardColor = const Color(0xFFE65100);
      cardIcon = Icons.quiz_rounded;
      cardLabel = 'Pagsusulit';
      cardSubtitle = 'Magpatakbo ng\nmga pagsusulit';
    }

    return GestureDetector(
      onTap: _quizCheckDone ? _onQuizCardTapped : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(cardIcon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
            Text(cardLabel,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(cardSubtitle,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 11,
                    height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildPassBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        border: Border.all(color: const Color(0xFFA5D6A7), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Icon(Icons.verified_rounded, color: Color(0xFF2E7D32), size: 18),
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
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Color(0xFF9E9E9E),
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildLessonList() {
    if (lessons.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(color: Color(0xFFC62828)),
        ),
      );
    }

    return Column(
      children: List.generate(lessons.length, (index) {
        final isSelected = selectedLessonIndex == index;
        final isCompleted = completedLessonIndex == index;
        final lessonTitle =
            lessons[index]['aralin_title'] ?? 'Aralin ${index + 1}';

        Color dotBg;
        Widget dotIcon;
        if (isSelected) {
          dotBg = const Color(0xFFFFEBEE);
          dotIcon = const Icon(Icons.play_arrow_rounded,
              color: Color(0xFFC62828), size: 16);
        } else if (isCompleted) {
          dotBg = const Color(0xFFE8F5E9);
          dotIcon = const Icon(Icons.check_rounded,
              color: Color(0xFF2E7D32), size: 16);
        } else {
          dotBg = const Color(0xFFF0F0F0);
          dotIcon = const Icon(Icons.circle_outlined,
              color: Color(0xFF9E9E9E), size: 14);
        }

        return GestureDetector(
          onTap: () {
            if (lessons.isNotEmpty && index < lessons.length) {
              setState(() {
                selectedLessonIndex = index;
                completedLessonIndex = index;
                _quizCheckDone = false;
                _quizCompleted = null;
              });
              _checkQuizCompletion();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFC62828)
                    : const Color(0xFFE0E0E0),
                width: isSelected ? 1.5 : 0.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: dotBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: dotIcon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lessonTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFFC62828)
                              : const Color(0xFF212121),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSelected
                            ? 'Kasalukuyang pinipili'
                            : 'I-tap upang pumili',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFBDBDBD), size: 18),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSummaryCard() {
    if (lessons.isEmpty) return const SizedBox.shrink();

    final idx = selectedLessonIndex ?? 0;
    final title = lessons[idx]['aralin_title'] ?? 'Walang Pamagat';
    final summary = lessons[idx]['summary'] ?? 'Walang buod.';
    final details = (lessons[idx]['details'] ?? '') as String;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
      borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            color: const Color(0xFFC62828),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Aralin ${idx + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Buod',
                      style: TextStyle(fontSize: 11, color: Color(0xFF757575))),
                ),
                const SizedBox(height: 10),
                Text(
                  summary,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF616161),
                      height: 1.6),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...details
                      .split('\n')
                      .where((d) => d.trim().isNotEmpty)
                      .map(
                        (d) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ',
                                  style: TextStyle(
                                      color: Color(0xFFC62828), fontSize: 13)),
                              Expanded(
                                child: Text(d,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF616161),
                                        height: 1.5)),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ],
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LessonScreen(
                          id: widget.id,
                          aralinId: _currentAralinId,
                          sessionId: widget.sessionId,
                          antasId: widget.antasId,
                          lessonId: _currentAralinId,
                        ),
                      ),
                    ).then((_) => _checkQuizCompletion());
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.play_circle_rounded,
                            color: Color(0xFFC62828), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Panoorin ang bidyo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFC62828),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}