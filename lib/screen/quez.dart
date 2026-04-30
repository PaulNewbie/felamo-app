import 'package:felamo/baseurl/baseurl.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math';
import 'package:felamo/screen/quiz_history.dart';

class QuizScreen extends StatefulWidget {
  final int antasId;
  final String sessionId;
  final int aralinId;

  const QuizScreen({
    super.key,
    required this.antasId,
    required this.sessionId,
    required this.aralinId,
  });

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  // ── Question data ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> questions = [];

  List<Map<String, dynamic>> multipleChoiceAnswers = [];
  List<Map<String, dynamic>> trueOrFalseAnswers    = [];
  List<Map<String, dynamic>> identificationAnswers = [];
  List<Map<String, dynamic>> jumbledWordsAnswers   = [];

  Map<int, String> userAnswers = {};

  // ── UI state ───────────────────────────────────────────────────────────────
  int     currentIndex    = 0;
  String? selectedAnswer;
  TextEditingController textController = TextEditingController();
  int?    assessmentId;
  bool    isLoading       = true;
  bool    showCorrection  = false;

  // ── Timer ──────────────────────────────────────────────────────────────────
  Timer?   _timer;
  Duration _timeRemaining = const Duration(seconds: 40);

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _animationController;
  late Animation<double>   _fadeAnimation;

  // ── Jumbled word helpers ───────────────────────────────────────────────────
  /// Returns a scrambled version of [word] guaranteed to differ from original
  String _scrambleWord(String word) {
    if (word.length <= 1) return word;
    final chars = word.toUpperCase().split('');
    final rng = Random();
    String scrambled;
    int attempts = 0;
    do {
      chars.shuffle(rng);
      scrambled = chars.join();
      attempts++;
    } while (scrambled == word.toUpperCase() && attempts < 20);
    return scrambled;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    fetchQuestions();
    _startTimer();
    _animationController.forward();
  }

  @override
  void dispose() {
    textController.dispose();
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // ── Timer helpers ──────────────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining.inSeconds <= 0) {
        nextQuestion(isTimeout: true);
      } else {
        if (mounted) {
          setState(() {
            _timeRemaining = _timeRemaining - const Duration(seconds: 1);
          });
        }
      }
    });
  }

  String _formatDuration(Duration duration) {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Fetch questions from server ────────────────────────────────────────────
  Future<void> fetchQuestions() async {
    if (mounted) setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("${baseUrl}get-assessment.php"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "session_id": widget.sessionId,
          "aralin_id": widget.aralinId,
        }),
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        _showFetchError('Server error: HTTP ${response.statusCode}');
        return;
      }

      final data = jsonDecode(response.body);

      if (data['status'] == 'already_taken') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QuizHistoryScreen(
              sessionId: widget.sessionId,
              aralinId:  widget.aralinId,
            ),
          ),
        );
        return;
      }

      if (data['status'] != 'success') {
        _showFetchError(data['message'] ?? 'May nangyaring mali sa pagkuha ng pagsusulit.');
        return;
      }

      if (data['data'] != null && data['data']['assessment'] != null) {
        assessmentId = data['data']['assessment']['id'] as int?;
      }

      final List<Map<String, dynamic>> loadedQuestions = [];

      for (var q in (data['data']?['multiple_choices'] ?? [])) {
        if (q['id'] == null || q['question'] == null) continue;
        loadedQuestions.add({
          'type':           'multiple',
          'id':             q['id'],
          'question':       q['question'],
          'choices': {
            'A': q['choice_a'] ?? '',
            'B': q['choice_b'] ?? '',
            'C': q['choice_c'] ?? '',
            'D': q['choice_d'] ?? '',
          },
          'correct_answer': q['correct_answer'],
          'difficulty':     q['difficulty'] ?? 'medium',
        });
      }

      for (var q in (data['data']?['true_or_false'] ?? [])) {
        if (q['id'] == null || q['question'] == null) continue;
        loadedQuestions.add({
          'type':           'boolean',
          'id':             q['id'],
          'question':       q['question'],
          'choices':        {'A': 'Tama', 'B': 'Mali'},
          'correct_answer': q['answer'] == 1 ? 'A' : 'B',
          'difficulty':     q['difficulty'] ?? 'medium',
        });
      }

      for (var q in (data['data']?['identification'] ?? [])) {
        if (q['id'] == null || q['question'] == null) continue;
        loadedQuestions.add({
          'type':           'identification',
          'id':             q['id'],
          'question':       q['question'],
          'correct_answer': q['answer'],
          'difficulty':     q['difficulty'] ?? 'medium',
        });
      }

      for (var q in (data['data']?['jumbled_words'] ?? [])) {
        if (q['id'] == null || q['question'] == null) continue;
        // Pre-compute scrambled letters once per question
        final correctWord = (q['answer'] ?? '').toString();
        final scrambled   = _scrambleWord(correctWord);
        loadedQuestions.add({
          'type':           'jumbled',
          'id':             q['id'],
          'question':       q['question'],   // instruction text from DB
          'correct_answer': correctWord,
          'scrambled':      scrambled,       // pre-computed scramble for display
          'difficulty':     q['difficulty'] ?? 'medium',
        });
      }

      if (loadedQuestions.isEmpty) {
        _showFetchError('Walang mga katanungan na magagamit para sa pagsusulit na ito.');
        return;
      }

      loadedQuestions.shuffle();

      if (mounted) {
        setState(() {
          questions  = loadedQuestions;
          isLoading  = false;
        });
      }
    } catch (e) {
      _showFetchError('May nangyaring mali sa koneksyon: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ── Answer submission helpers ──────────────────────────────────────────────
  Future<void> nextQuestion({bool isTimeout = false}) async {
    if (questions.isEmpty) return;

    _timer?.cancel();

    final question = questions[currentIndex];
    final isTextType =
        question['type'] == 'identification' || question['type'] == 'jumbled';

    String? answer =
        isTextType ? textController.text.trim() : selectedAnswer;

    if (isTimeout) {
      answer = "";
    } else if (answer == null || answer.isEmpty) {
      _startTimer();
      return;
    }

    if (mounted) setState(() => showCorrection = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    userAnswers[currentIndex] = answer;
    _recordAnswer(question, answer);

    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
        selectedAnswer  = null;
        textController.text = '';
        showCorrection  = false;
        _timeRemaining  = const Duration(seconds: 40);
      });
      _startTimer();
    } else {
      await submitAnswers();
    }
  }

  void _recordAnswer(Map<String, dynamic> question, String answer) {
    final id = question['id'] as int;

    switch (question['type']) {
      case 'multiple':
        multipleChoiceAnswers.removeWhere((a) => a['question_id'] == id);
        multipleChoiceAnswers.add({'question_id': id, 'answer': answer});
        break;
      case 'boolean':
        trueOrFalseAnswers.removeWhere((a) => a['question_id'] == id);
        trueOrFalseAnswers.add({
          'question_id': id,
          'answer': answer == 'A' ? 1 : 0,
        });
        break;
      case 'identification':
        identificationAnswers.removeWhere((a) => a['question_id'] == id);
        identificationAnswers.add({'question_id': id, 'answer': answer});
        break;
      case 'jumbled':
        jumbledWordsAnswers.removeWhere((a) => a['question_id'] == id);
        jumbledWordsAnswers.add({'question_id': id, 'answer': answer});
        break;
    }
  }

  // ── Submit to server ───────────────────────────────────────────────────────
  Future<void> submitAnswers() async {
    try {
      final response = await http.post(
        Uri.parse("${baseUrl}submit-assessment.php"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "session_id":    widget.sessionId,
          "assessment_id": assessmentId ?? 0,
          "multiple_choices": multipleChoiceAnswers,
          "true_or_false":    trueOrFalseAnswers,
          "identification":   identificationAnswers,
          "jumbled_words":    jumbledWordsAnswers,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          final int rawPoints   = data['raw_points']   ?? 0;
          final int totalItems  = data['total_items']  ?? questions.length;
          final int bonusPoints = data['bonus_points'] ?? 0;
          final bool firstPass  = data['first_pass']   ?? true;
          _showPassDialog(rawPoints, totalItems, bonusPoints, firstPass);
        } else if (data['status'] == 'failed') {
          final int rawPoints  = data['raw_points']  ?? 0;
          final int totalItems = data['total_items'] ?? questions.length;
          final int pct        = data['percentage']  ?? 0;
          final int attempts   = data['attempts']    ?? 1;
          _showFailDialog(rawPoints, totalItems, pct, attempts);
        } else if (data['status'] == 'already_taken') {
          _showAlreadyTakenDialog();
        } else {
          _showFetchError(data['message'] ?? 'Hindi maibigay ang resulta.');
        }
      } else {
        _showFetchError('Server error: HTTP ${response.statusCode}');
      }
    } catch (e) {
      _showFetchError('Network error: $e');
    }
  }

  // ── Result dialogs ─────────────────────────────────────────────────────────
  void _showPassDialog(int rawPoints, int totalItems, int bonusPoints, bool firstPass) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
        isPass: true,
        score: rawPoints,
        total: totalItems,
        bonusPoints: bonusPoints,
        firstPass: firstPass,
        onDismiss: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showFailDialog(int rawPoints, int totalItems, int pct, int attempts) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
        isPass: false,
        score: rawPoints,
        total: totalItems,
        percentage: pct,
        attempts: attempts,
        onDismiss: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showAlreadyTakenDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Tapos Mo Na!',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 22, color: Colors.green[700])),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 16),
          Text('Nasagutan mo na ang pagsusulit na ito.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 15)),
        ]),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => QuizHistoryScreen(
                    sessionId: widget.sessionId, aralinId: widget.aralinId))),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Tingnan ang Kasaysayan',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showFetchError(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Paalala', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
        content: Text(message, style: GoogleFonts.poppins(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(); },
            child: Text('Bumalik', style: GoogleFonts.poppins(color: Colors.red[700])),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: _buildLoadingBody(),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Center(
          child: Text('Walang mga katanungan.',
              style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[700])),
        ),
      );
    }

    final question = questions[currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildTopBar(),
            _buildProgressSection(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildQuestionCard(question),
                    const SizedBox(height: 16),
                    _buildAnswerSection(question),
                    const SizedBox(height: 20),
                    _buildNextButton(question),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────────
  Widget _buildLoadingBody() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8B0000), Color(0xFFC62828)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            const SizedBox(height: 20),
            Text('Inihahanda ang pagsusulit...',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    final pct = _timeRemaining.inSeconds / 40.0;
    final isUrgent = _timeRemaining.inSeconds <= 10;
    final isWarning = _timeRemaining.inSeconds <= 20;

    Color timerColor;
    if (isUrgent)        timerColor = const Color(0xFFE53935);
    else if (isWarning)  timerColor = const Color(0xFFFB8C00);
    else                 timerColor = const Color(0xFF388E3C);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8B0000), Color(0xFFC62828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              // Back button
              _CircleButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () { _timer?.cancel(); Navigator.pop(context); },
              ),
              const SizedBox(width: 12),
              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pagsusulit',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                    Text('Tanong ${currentIndex + 1} sa ${questions.length}',
                        style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              // Timer pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? Colors.red[900]
                      : isWarning
                          ? Colors.orange[700]
                          : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: timerColor.withOpacity(0.6),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      _formatDuration(_timeRemaining),
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
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

  // ── Progress Section ───────────────────────────────────────────────────────
  Widget _buildProgressSection() {
    final progress = (currentIndex + 1) / questions.length;
    return Container(
      color: const Color(0xFFC62828),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: Colors.white.withOpacity(0.25),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD54F)),
        ),
      ),
    );
  }

  // ── Question Card ──────────────────────────────────────────────────────────
  Widget _buildQuestionCard(Map<String, dynamic> question) {
    final type       = question['type'] as String;
    final difficulty = (question['difficulty'] ?? 'medium').toString().toLowerCase().trim();
    final instruction = _instructionFor(type);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip with type + difficulty
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F8),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
            ),
            child: Row(
              children: [
                _TypeBadge(type: type),
                const SizedBox(width: 8),
                _DifficultyBadge(difficulty: difficulty),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC62828).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${currentIndex + 1}/${questions.length}',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFC62828)),
                  ),
                ),
              ],
            ),
          ),
          // Question body
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(instruction,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[500])),
                const SizedBox(height: 10),
                Text(
                  question['question'] ?? '',
                  style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                      height: 1.5),
                ),
                // Jumbled letters display
                if (type == 'jumbled') ...[
                  const SizedBox(height: 16),
                  _buildJumbledLetterTiles(question['scrambled'] ?? ''),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Jumbled letter tiles ───────────────────────────────────────────────────
  Widget _buildJumbledLetterTiles(String scrambled) {
    final letters = scrambled.split('');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mga titik na ayusin:',
            style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: letters.map((letter) {
            return Container(
              width: 36,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF8B0000),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B0000).withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  letter,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Answer Section ─────────────────────────────────────────────────────────
  Widget _buildAnswerSection(Map<String, dynamic> question) {
    if (question['type'] == 'multiple' || question['type'] == 'boolean') {
      return Column(
        children: (question['choices'] as Map<String, dynamic>).entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildChoiceOption(entry.key, entry.value.toString(), question),
          );
        }).toList(),
      );
    }

    // Text input (identification / jumbled)
    return _buildTextInput(question);
  }

  // ── Choice Option ──────────────────────────────────────────────────────────
  Widget _buildChoiceOption(String letter, String text, Map<String, dynamic> question) {
    final isSelected = selectedAnswer == letter;
    final correctKey = question['correct_answer']?.toString().toLowerCase().trim() ?? '';
    final isCorrect  = letter.toLowerCase() == correctKey || text.toLowerCase().trim() == correctKey;

    // Color logic
    Color bgColor, borderColor, letterBg;
    Color textColor = const Color(0xFF1A1A1A);

    if (showCorrection) {
      if (isCorrect) {
        bgColor     = const Color(0xFFE8F5E9);
        borderColor = const Color(0xFF388E3C);
        letterBg    = const Color(0xFF388E3C);
        textColor   = const Color(0xFF1B5E20);
      } else if (isSelected) {
        bgColor     = const Color(0xFFFFEBEE);
        borderColor = const Color(0xFFC62828);
        letterBg    = const Color(0xFFC62828);
        textColor   = const Color(0xFFB71C1C);
      } else {
        bgColor     = Colors.white;
        borderColor = Colors.grey.shade200;
        letterBg    = Colors.grey.shade300;
      }
    } else if (isSelected) {
      bgColor     = const Color(0xFFFFF3E0);
      borderColor = const Color(0xFFE65100);
      letterBg    = const Color(0xFFE65100);
      textColor   = const Color(0xFFE65100);
    } else {
      bgColor     = Colors.white;
      borderColor = Colors.grey.shade200;
      letterBg    = Colors.grey.shade200;
    }

    return GestureDetector(
      onTap: showCorrection ? null : () => setState(() => selectedAnswer = letter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: isSelected || (showCorrection && isCorrect) ? 2 : 1),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected && !showCorrection
              ? [BoxShadow(color: const Color(0xFFE65100).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(
          children: [
            // Letter circle
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: letterBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(letter,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(text,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: textColor,
                      fontWeight: isSelected || (showCorrection && isCorrect)
                          ? FontWeight.w600
                          : FontWeight.w400)),
            ),
            if (showCorrection && isCorrect)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF388E3C), size: 22),
            if (showCorrection && isSelected && !isCorrect)
              const Icon(Icons.cancel_rounded, color: Color(0xFFC62828), size: 22),
          ],
        ),
      ),
    );
  }

  // ── Text Input ─────────────────────────────────────────────────────────────
  Widget _buildTextInput(Map<String, dynamic> question) {
    final isTextType = question['type'] == 'identification' || question['type'] == 'jumbled';
    final typed = textController.text.trim().toLowerCase();
    final correct = question['correct_answer']?.toString().toLowerCase() ?? '';
    final isUserCorrect = typed == correct;

    Color borderColor = Colors.grey.shade300;
    Color fillColor   = Colors.white;
    if (showCorrection) {
      borderColor = isUserCorrect ? const Color(0xFF388E3C) : const Color(0xFFC62828);
      fillColor   = isUserCorrect ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: showCorrection ? 2 : 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: textController,
            enabled: !showCorrection,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintText: question['type'] == 'jumbled'
                  ? 'I-type ang tamang sagot...'
                  : 'Isulat ang iyong sagot dito...',
              hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
              suffixIcon: showCorrection
                  ? Icon(
                      isUserCorrect ? Icons.check_circle : Icons.cancel,
                      color: isUserCorrect ? const Color(0xFF388E3C) : const Color(0xFFC62828),
                    )
                  : null,
            ),
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            onChanged: (v) => setState(() => userAnswers[currentIndex] = v),
          ),
        ),
        // Show correct answer when wrong
        if (showCorrection && !isUserCorrect) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF388E3C).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_rounded, color: Color(0xFF388E3C), size: 18),
                const SizedBox(width: 8),
                Text('Tamang sagot: ',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey[600])),
                Text(question['correct_answer']?.toString() ?? '',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1B5E20))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Next Button ────────────────────────────────────────────────────────────
  Widget _buildNextButton(Map<String, dynamic> question) {
    final isTextType = question['type'] == 'identification' || question['type'] == 'jumbled';
    final isEnabled = !showCorrection &&
        (isTextType ? textController.text.trim().isNotEmpty : selectedAnswer != null);
    final isLast = currentIndex == questions.length - 1;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ElevatedButton(
          onPressed: isEnabled ? nextQuestion : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isEnabled ? const Color(0xFFC62828) : Colors.grey.shade300,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade200,
            disabledForegroundColor: Colors.grey.shade400,
            elevation: isEnabled ? 4 : 0,
            shadowColor: const Color(0xFFC62828).withOpacity(0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isLast ? 'Tapusin ang Pagsusulit' : 'Susunod na Tanong',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isEnabled ? Colors.white : Colors.grey.shade400),
              ),
              const SizedBox(width: 8),
              Icon(
                isLast ? Icons.flag_rounded : Icons.arrow_forward_rounded,
                size: 18,
                color: isEnabled ? Colors.white : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Static label helpers ───────────────────────────────────────────────────
  String _instructionFor(String type) {
    switch (type) {
      case 'multiple': return 'Piliin ang tamang sagot';
      case 'boolean':  return 'Tama o Mali?';
      case 'identification': return 'Isulat ang tamang sagot';
      case 'jumbled':  return 'Ayusin ang mga titik para makabuo ng tamang salita';
      default:         return '';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SUPPORTING WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

/// Circular icon button used in the top bar
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

/// Question type badge
class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final Map<String, _BadgeConfig> cfg = {
      'multiple':       _BadgeConfig('Multiple Choice', const Color(0xFF1565C0), const Color(0xFFE3F2FD)),
      'boolean':        _BadgeConfig('Tama o Mali',     const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
      'identification': _BadgeConfig('Identification',  const Color(0xFF6A1B9A), const Color(0xFFF3E5F5)),
      'jumbled':        _BadgeConfig('Jumbled Word',    const Color(0xFFE65100), const Color(0xFFFFF3E0)),
    };
    final c = cfg[type] ?? _BadgeConfig(type, Colors.grey, Colors.grey.shade100);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(c.label,
          style: GoogleFonts.poppins(
              fontSize: 10, fontWeight: FontWeight.w700, color: c.color)),
    );
  }
}

/// Difficulty badge — FIX: maps raw DB strings (easy/medium/hard) correctly
class _DifficultyBadge extends StatelessWidget {
  final String difficulty;
  const _DifficultyBadge({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    // Normalise: trim, lowercase — handles any whitespace/case from DB
    final d = difficulty.trim().toLowerCase();

    String label;
    Color color;
    Color bg;

    // Explicit mapping so only exact strings match
    if (d == 'easy') {
      label = 'Madali';
      color = const Color(0xFF2E7D32);
      bg    = const Color(0xFFE8F5E9);
    } else if (d == 'hard') {
      label = 'Mahirap';
      color = const Color(0xFFC62828);
      bg    = const Color(0xFFFFEBEE);
    } else {
      // 'medium' or anything else defaults here
      label = 'Katamtaman';
      color = const Color(0xFFE65100);
      bg    = const Color(0xFFFFF3E0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _BadgeConfig {
  final String label;
  final Color color;
  final Color bg;
  const _BadgeConfig(this.label, this.color, this.bg);
}

// ═══════════════════════════════════════════════════════════════════════════
// RESULT DIALOG
// ═══════════════════════════════════════════════════════════════════════════
class _ResultDialog extends StatelessWidget {
  final bool     isPass;
  final int      score;
  final int      total;
  final int      bonusPoints;
  final bool     firstPass;
  final int      percentage;
  final int      attempts;
  final VoidCallback onDismiss;

  const _ResultDialog({
    required this.isPass,
    required this.score,
    required this.total,
    this.bonusPoints = 0,
    this.firstPass   = false,
    this.percentage  = 0,
    this.attempts    = 1,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final pct  = total > 0 ? ((score / total) * 100).round() : 0;
    final color = isPass ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final bg    = isPass ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon circle
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(
                isPass ? Icons.emoji_events_rounded : Icons.replay_rounded,
                color: color,
                size: 42,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isPass ? 'Mahusay! Pumasa Ka!' : 'Hindi Pumasa',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 12),
            // Score row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$score',
                      style: GoogleFonts.poppins(
                          fontSize: 40, fontWeight: FontWeight.w900, color: color)),
                  Text(' / $total',
                      style: GoogleFonts.poppins(
                          fontSize: 22, fontWeight: FontWeight.w600, color: color.withOpacity(0.6))),
                  const SizedBox(width: 12),
                  Text('$pct%',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w700, color: color.withOpacity(0.8))),
                ],
              ),
            ),
            if (isPass && firstPass && bonusPoints > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                    const SizedBox(width: 6),
                    Text('+$bonusPoints bonus puntos!',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: Colors.orange[800],
                            fontSize: 13)),
                  ],
                ),
              ),
            ],
            if (!isPass) ...[
              const SizedBox(height: 10),
              Text(
                'Kailangan ng 80% para pumasa.\nPanoorin muli ang bidyo bago subukan muli.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600], height: 1.5),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  isPass ? 'Bumalik sa Aralin' : 'Panoorin Muli ang Bidyo',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}