import 'package:felamo/baseurl/baseurl.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
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

  // FIX: Separate answer buckets per question type.
  // Each bucket only contains answers for questions of that type,
  // matching exactly what the PHP grader expects.
  List<Map<String, dynamic>> multipleChoiceAnswers = [];
  List<Map<String, dynamic>> trueOrFalseAnswers    = [];
  List<Map<String, dynamic>> identificationAnswers = [];
  List<Map<String, dynamic>> jumbledWordsAnswers   = [];

  // Track what the user has selected so far (index → answer)
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
          // FIX: Send aralin_id (not antasId/level_id) so the PHP endpoint
          // looks up the assessment that belongs to THIS specific aralin.
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
        // Redirect to history for THIS aralin — not a generic block
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QuizHistoryScreen(
              sessionId: widget.sessionId,
              aralinId:  widget.aralinId, // scoped to this aralin
            ),
          ),
        );
        return;
      }

      if (data['status'] != 'success') {
        _showFetchError(data['message'] ?? 'May nangyaring mali sa pagkuha ng pagsusulit.');
        return;
      }

      // ── Parse assessment_id ───────────────────────────────────────────────
      if (data['data'] != null && data['data']['assessment'] != null) {
        assessmentId = data['data']['assessment']['id'] as int?;
      }

      // ── Build the flat question list ──────────────────────────────────────
      // FIX: Load exactly what the server sends — do NOT cap at 15 on the
      // Flutter side. The PHP already respects the actual item count per
      // aralin (e.g. 13 for Aralin 1, 15 for Aralin 2).
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
        });
      }

      for (var q in (data['data']?['identification'] ?? [])) {
        if (q['id'] == null || q['question'] == null) continue;
        loadedQuestions.add({
          'type':           'identification',
          'id':             q['id'],
          'question':       q['question'],
          'correct_answer': q['answer'],
        });
      }

      for (var q in (data['data']?['jumbled_words'] ?? [])) {
        if (q['id'] == null || q['question'] == null) continue;
        loadedQuestions.add({
          'type':           'jumbled',
          'id':             q['id'],
          'question':       q['question'],
          'correct_answer': q['answer'],
        });
      }

      if (loadedQuestions.isEmpty) {
        _showFetchError('Walang mga katanungan na magagamit para sa pagsusulit na ito.');
        return;
      }

      // Shuffle the combined list so types are interleaved on screen
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

    // Show correction colours for 2 seconds
    if (mounted) setState(() => showCorrection = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Record the answer in the correct typed bucket
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

  /// Stores the answer in the correct typed bucket so the PHP grader
  /// receives exactly what it expects for each question type.
  void _recordAnswer(Map<String, dynamic> question, String answer) {
    final id = question['id'] as int;

    switch (question['type']) {
      case 'multiple':
        multipleChoiceAnswers.removeWhere((a) => a['question_id'] == id);
        multipleChoiceAnswers.add({'question_id': id, 'answer': answer});
        break;
      case 'boolean':
        trueOrFalseAnswers.removeWhere((a) => a['question_id'] == id);
        // PHP grader expects 1 for True (A) and 0 for False (B)
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
          // FIX: Pass each typed bucket separately so the PHP grader can
          // apply the correct comparison logic per type (e.g. A/B for MCQ,
          // 1/0 for true/false, text for identification/jumbled).
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

  void _showPassDialog(
      int rawPoints, int totalItems, int bonusPoints, bool firstPass) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Mahusay!',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.green[700]),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/taho.png', height: 120,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.emoji_events, size: 100, color: Colors.amber)),
            const SizedBox(height: 12),
            Text('Pumasa ka! $rawPoints / $totalItems',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 16)),
            if (firstPass && bonusPoints > 0)
              Text('+$bonusPoints bonus puntos',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600)),
            if (!firstPass)
              Text('Na-record na ang iyong naunang pagpasa.',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey[600]),
                  textAlign: TextAlign.center),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // back to AntasPage
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Bumalik sa Aralin',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showFailDialog(
      int rawPoints, int totalItems, int pct, int attempts) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hindi Pumasa',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.red[800])),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, size: 80, color: Colors.orange[700]),
            const SizedBox(height: 12),
            Text('Ang iyong puntos: $rawPoints / $totalItems ($pct%)',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 15)),
            const SizedBox(height: 8),
            Text(
                'Kailangan ang 80% para pumasa.\n'
                'Panoorin muli ang bidyo bago subukang muli.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 14, color: Colors.grey[700])),
            const SizedBox(height: 6),
            Text('Pagtatangka #$attempts',
                style:
                    GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // back to AntasPage to rewatch
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Panoorin Muli ang Bidyo',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
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
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.green[700])),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/maligaya.png', height: 120,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.check_circle, size: 100, color: Colors.green)),
            const SizedBox(height: 16),
            Text(
                'Nasagutan mo na ang pagsusulit na ito dati. Magaling!\n\n'
                'Ipagpatuloy lang ang pag-aaral.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[800])),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => QuizHistoryScreen(
                    sessionId: widget.sessionId,
                    aralinId:  widget.aralinId, // scoped to THIS aralin
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Tingnan ang Kasaysayan',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white)),
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
        title: Text('Paalala',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.orange[800])),
        content: Text(message,
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[800])),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('Bumalik',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, color: Colors.red[700])),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: Center(child: CircularProgressIndicator(color: Colors.red[700])),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: Center(
          child: Text('Walang mga katanungan.',
              style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[800])),
        ),
      );
    }

    final question = questions[currentIndex];
    final String instruction = _instructionFor(question['type']);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: Colors.grey[100],
          child: Column(
            children: [
              // Progress bar
              const SizedBox(height: 16),
              _buildProgressBar(),
              const SizedBox(height: 24),

              // Question card
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question label
                      Text(
                        'Tanong ${currentIndex + 1} (${_typeLabel(question['type'])})',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.red[800],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Instruction
                      Text(instruction,
                          style: GoogleFonts.poppins(
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                              color: Colors.grey[600])),
                      const SizedBox(height: 16),

                      // Question text
                      Text(question['question'] ?? '',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.grey[900])),
                      const SizedBox(height: 24),

                      // Answer area
                      Expanded(child: _buildAnswerArea(question)),

                      const SizedBox(height: 24),

                      // Next button
                      _buildNextButton(question),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.red[700],
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [Colors.red[500]!, Colors.red[700]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            _timer?.cancel();
            Navigator.pop(context);
          },
        ),
      ),
      title: Row(
        children: [
          Text('Pagsusulit',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.white)),
          const Spacer(),
          // Timer chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _timeRemaining.inSeconds <= 10
                  ? Colors.red[900]
                  : _timeRemaining.inSeconds <= 20
                      ? Colors.orange[700]
                      : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('⏰ ${_formatDuration(_timeRemaining)}',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _timeRemaining.inSeconds <= 20
                        ? Colors.white
                        : Colors.red[700])),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.red[600]!, Colors.red[800]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Text('Progreso',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                // FIX: denominator is questions.length (actual item count
                // from server) — not a hardcoded 15
                value: (currentIndex + 1) / questions.length,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.yellow[700]!),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // FIX: Display actual count (e.g. "3/13" for Aralin 1, "3/15" for Aralin 2)
          Text('${currentIndex + 1}/${questions.length}',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildAnswerArea(Map<String, dynamic> question) {
    if (question['type'] == 'multiple' || question['type'] == 'boolean') {
      return ListView(
        // FIX: Cast as Map<String, dynamic> to prevent JSON parsing crashes
        children: (question['choices'] as Map<String, dynamic>)
            .entries
            .map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  // FIX: Add .toString() to the value
                  child: _buildAnswerOption(entry.key, entry.value.toString(), question),
                ))
            .toList(),
      );}

    // Identification / Jumbled
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question['type'] == 'identification'
              ? 'Isulat ang tamang sagot:'
              : 'Ayusin ang mga salita upang mabuo ang tamang sagot:',
          style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800]),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: textController,
          enabled: !showCorrection,
          decoration: InputDecoration(
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _textFieldBorderColor(question))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _textFieldBorderColor(question))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red[700]!, width: 2)),
            hintText: question['type'] == 'identification'
                ? 'Ilagay ang sagot'
                : 'Ilagay ang naayos na salita',
            filled: true,
            fillColor: showCorrection
                ? (textController.text.trim().toLowerCase() ==
                        question['correct_answer'].toString().toLowerCase()
                    ? Colors.green[50]
                    : Colors.red[50])
                : Colors.grey[100],
          ),
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[800]),
          onChanged: (v) => setState(() => userAnswers[currentIndex] = v),
        ),
        if (showCorrection &&
            textController.text.trim().toLowerCase() !=
                question['correct_answer'].toString().toLowerCase())
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Text('Tamang Sagot: ${question['correct_answer']}',
                style: GoogleFonts.poppins(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
      ],
    );
  }

  Color _textFieldBorderColor(Map<String, dynamic> question) {
    if (!showCorrection) return Colors.grey[300]!;
    return textController.text.trim().toLowerCase() ==
            question['correct_answer'].toString().toLowerCase()
        ? Colors.green[700]!
        : Colors.red[700]!;
  }

  Widget _buildNextButton(Map<String, dynamic> question) {
    final isTextType =
        question['type'] == 'identification' || question['type'] == 'jumbled';
    final isEnabled = !showCorrection &&
        (isTextType
            ? textController.text.trim().isNotEmpty
            : selectedAnswer != null);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isEnabled ? nextQuestion : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: Text(
          currentIndex < questions.length - 1 ? "Susunod" : "Tapusin",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildAnswerOption(
      String letter, String text, Map<String, dynamic> question) {
    final isSelected  = selectedAnswer == letter;
    final correctKey = question['correct_answer']?.toString().toLowerCase().trim() ?? '';
    final isCorrect = letter.toLowerCase() == correctKey || text.toLowerCase().trim() == correctKey;

    Color? bgColor      = isSelected ? Colors.blue[50] : Colors.white;
    Color  borderColor  = isSelected ? Colors.blue[700]! : Colors.grey[300]!;
    Color  gradStart    = isSelected ? Colors.blue[500]! : Colors.grey[400]!;
    Color  gradEnd      = isSelected ? Colors.blue[700]! : Colors.grey[600]!;
    Color  textColor    = isSelected ? Colors.blue[800]! : Colors.grey[800]!;

    if (showCorrection) {
      if (isCorrect) {
        bgColor = Colors.green[50]; borderColor = Colors.green[700]!;
        gradStart = Colors.green[500]!; gradEnd = Colors.green[700]!;
        textColor = Colors.green[800]!;
      } else if (isSelected) {
        bgColor = Colors.red[50]; borderColor = Colors.red[700]!;
        gradStart = Colors.red[500]!; gradEnd = Colors.red[700]!;
        textColor = Colors.red[800]!;
      }
    }

    return GestureDetector(
      onTap: showCorrection
          ? null
          : () => setState(() => selectedAnswer = letter),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [gradStart, gradEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(letter,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(text,
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: textColor,
                      fontWeight: isSelected ||
                              (showCorrection && isCorrect)
                          ? FontWeight.bold
                          : FontWeight.normal)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Static label helpers ───────────────────────────────────────────────────

  String _instructionFor(String type) {
    switch (type) {
      case 'multiple':      return 'Panuto: Pumili ng isang letra';
      case 'boolean':       return 'Panuto: Sagutin kung tama ba o mali';
      case 'identification':return 'Panuto: Isulat ang wastong sagot sa bawat patlang';
      case 'jumbled':
        return 'Panuto: Ayusin ang mga ginulong letra upang maibigay ang tamang kasagutan';
      default:              return '';
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'multiple':       return 'Multiple Choice';
      case 'boolean':        return 'True/False';
      case 'identification': return 'Identification';
      case 'jumbled':        return 'Jumbled Words';
      default:               return type;
    }
  }
}