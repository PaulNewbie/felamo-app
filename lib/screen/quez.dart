import 'package:felamo/baseurl/baseurl.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

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

class _QuizScreenState extends State<QuizScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> questions = [];
  List<Map<String, dynamic>> multipleChoiceAnswers = [];
  List<Map<String, dynamic>> trueOrFalseAnswers = [];
  List<Map<String, dynamic>> identificationAnswers = [];
  List<Map<String, dynamic>> jumbledWordsAnswers = [];
  Map<int, String> userAnswers = {};
  int currentIndex = 0;
  String? selectedAnswer;
  TextEditingController textController = TextEditingController();
  int? assessmentId;
  bool isLoading = true;
  Timer? _timer;
  Duration _timeRemaining = const Duration(seconds: 40);
  bool showCorrection = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    print('QuizScreen initialized with:');
    print('antasId: ${widget.antasId}');
    print('sessionId: ${widget.sessionId}');
    print('aralinId: ${widget.aralinId}');
    fetchQuestions();
    _startTimer();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    textController.dispose();
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel(); // Cancel any existing timers
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining.inSeconds <= 0) {
        nextQuestion(isTimeout: true); // Auto-progress on timeout
      } else {
        setState(() {
          _timeRemaining = _timeRemaining - const Duration(seconds: 1);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> fetchQuestions() async {
    try {
      setState(() {
        isLoading = true;
      });

      final response = await http.post(
        Uri.parse("${baseUrl}get-assessment.php"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "session_id": widget.sessionId,
          "level_id": widget.antasId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] != 'success') {
          print('API Error in fetchQuestions: ${data['message'] ?? 'Unknown error'}');

          String message = (data['message'] ?? '').toString().toLowerCase();
          if (message.contains('already taken') || message.contains('taken')) {
            _showAlreadyTakenDialog();
          } else {
            _showFetchError(data['message'] ?? 'May nangyaring mali sa pagkuha ng pagsusulit.');
          }
          return;
        }

        final List<Map<String, dynamic>> loadedQuestions = [];

        if (data['data'] != null && data['data']['assessment'] != null) {
          assessmentId = data['data']['assessment']['id'];
        }

        if (data['data'] != null && data['data']['multiple_choices'] != null) {
          for (var q in data['data']['multiple_choices']) {
            if (q['id'] != null &&
                q['question'] != null &&
                q['choice_a'] != null &&
                q['choice_b'] != null &&
                q['choice_c'] != null &&
                q['choice_d'] != null &&
                q['correct_answer'] != null) {
              loadedQuestions.add({
                'type': 'multiple',
                'id': q['id'],
                'question': q['question'],
                'choices': {
                  'A': q['choice_a'],
                  'B': q['choice_b'],
                  'C': q['choice_c'],
                  'D': q['choice_d'],
                },
                'correct_answer': q['correct_answer'],
              });
            } else {
              print('Skipping invalid multiple-choice question: $q');
            }
          }
        }

        if (data['data'] != null && data['data']['true_or_false'] != null) {
          for (var q in data['data']['true_or_false']) {
            if (q['id'] != null && q['question'] != null && q['answer'] != null) {
              loadedQuestions.add({
                'type': 'boolean',
                'id': q['id'],
                'question': q['question'],
                'choices': {
                  'A': 'Tama',
                  'B': 'Mali',
                },
                'correct_answer': q['answer'] == 1 ? 'A' : 'B',
              });
            } else {
              print('Skipping invalid true/false question: $q');
            }
          }
        }

        if (data['data'] != null && data['data']['identification'] != null) {
          for (var q in data['data']['identification']) {
            if (q['id'] != null && q['question'] != null && q['answer'] != null) {
              loadedQuestions.add({
                'type': 'identification',
                'id': q['id'],
                'question': q['question'],
                'correct_answer': q['answer'],
              });
            } else {
              print('Skipping invalid identification question: $q');
            }
          }
        }

        if (data['data'] != null && data['data']['jumbled_words'] != null) {
          for (var q in data['data']['jumbled_words']) {
            if (q['id'] != null && q['question'] != null && q['answer'] != null) {
              loadedQuestions.add({
                'type': 'jumbled',
                'id': q['id'],
                'question': q['question'],
                'correct_answer': q['answer'],
              });
            } else {
              print('Skipping invalid jumbled words question: $q');
            }
          }
        }

        if (loadedQuestions.isEmpty) {
          print('No valid questions found in the response.');
          _showFetchError('Walang mga katanungan na magagamit para sa pagsusulit na ito.');
          return;
        }

        setState(() {
          questions = loadedQuestions;
          isLoading = false;
        });

        print('assessmentId: $assessmentId');
        print('Question IDs:');
        for (var question in questions) {
          print('Question ID: ${question['id']} (Type: ${question['type']})');
        }
      } else {
        print('HTTP Error in fetchQuestions: Status code ${response.statusCode}');
        _showFetchError('Server error: Hindi makuha ang pagsusulit.');
      }
    } catch (e) {
      print('Exception in fetchQuestions: $e');
      _showFetchError('May nangyaring mali sa koneksyon.');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showAlreadyTakenDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Tapos Mo Na!",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.green[700], // Green to show success/completion
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reusing your happy asset
            Image.asset(
              'assets/maligaya.png',
              height: 120,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.check_circle, size: 100, color: Colors.green),
            ),
            const SizedBox(height: 16),
            Text(
              "Nasagutan mo na ang pagsusulit na ito dati. Magaling!\n\nIpagpatuloy lang ang pag-aaral.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center, // Center the button
        actions: [
          ElevatedButton(
            onPressed: () {
              // This closes the dialog and pops all screens until it hits the Dashboard!
              Navigator.of(context).popUntil((route) => route.isFirst); 
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Bumalik sa Dashboard",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> nextQuestion({bool isTimeout = false}) async {
    if (questions.isEmpty) return;

    _timer?.cancel(); // 1. Stop the timer from ticking down

    final question = questions[currentIndex];
    String? answer = question['type'] == 'multiple' || question['type'] == 'boolean'
        ? selectedAnswer
        : textController.text.trim();

    if (isTimeout) {
      answer = ""; 
    } else if (answer == null || answer.isEmpty) {
      _startTimer(); // Restart timer if they clicked next without answering
      return; 
    }

    // 2. Show the correction colors
    setState(() {
      showCorrection = true; 
    });

    // 3. Wait for 2 seconds so the user can see the correct answer
    await Future.delayed(const Duration(seconds: 2));

    // 4. Save the answer and move on
    userAnswers[currentIndex] = answer;

    if (question['type'] == 'multiple') {
      multipleChoiceAnswers.removeWhere((ans) => ans["question_id"] == question['id']);
      multipleChoiceAnswers.add({"question_id": question['id'], "answer": answer});
    } else if (question['type'] == 'boolean') {
      trueOrFalseAnswers.removeWhere((ans) => ans["question_id"] == question['id']);
      trueOrFalseAnswers.add({"question_id": question['id'], "answer": answer == 'A' ? 1 : 0});
    } else if (question['type'] == 'identification') {
      identificationAnswers.removeWhere((ans) => ans["question_id"] == question['id']);
      identificationAnswers.add({"question_id": question['id'], "answer": answer});
    } else if (question['type'] == 'jumbled') {
      jumbledWordsAnswers.removeWhere((ans) => ans["question_id"] == question['id']);
      jumbledWordsAnswers.add({"question_id": question['id'], "answer": answer});
    }

    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
        selectedAnswer = null; 
        textController.text = ''; 
        showCorrection = false; // Hide correction colors for the new question
        _timeRemaining = const Duration(seconds: 40); // Reset timer to 40s
      });
      _startTimer(); // Start the timer again!
    } else {
      submitAnswers();
    }
  }

  // void previousQuestion() {
  //   if (currentIndex > 0) {
  //     setState(() {
  //       currentIndex--;
  //       selectedAnswer = questions[currentIndex]['type'] == 'multiple' || questions[currentIndex]['type'] == 'boolean'
  //           ? userAnswers[currentIndex]
  //           : null;
  //       textController.text = userAnswers[currentIndex] ?? '';
  //     });
  //   }
  // }

  void _showFetchError(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Paalala",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.orange[800], // Orange for notice/warning
          ),
        ),
        content: Text(
          message, // Shows the exact message from PHP (e.g., "You already taken this")
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.grey[800],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              Navigator.of(context).pop(); // Go back to Antas screen
            },
            child: Text(
              "Bumalik",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> submitAnswers() async {
    try {
      final url = Uri.parse("${baseUrl}submit-assessment.php");
      final requestBody = {
        "session_id": widget.sessionId,
        "assessment_id": assessmentId ?? 2,
        "multiple_choices": multipleChoiceAnswers,
        "true_or_false": trueOrFalseAnswers,
        "identification": identificationAnswers,
        "jumbled_words": jumbledWordsAnswers,
      };

      print('Submitting answers to: $url');
      print('Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('Submit Response:');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == "success") {
          int rawPoints = data['raw_points'] ?? 0;
          int bonusPoints = data['bonus_points'] ?? 35;

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                "Mahusay!",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Colors.red[800],
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/maligaya.png',
                    height: 150,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 150, color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Natapos mo na ang mga Pagsulit\nAng iyong puntos ay $rawPoints.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showRewardModal(rawPoints, bonusPoints);
                  },
                  child: Text(
                    "OK",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          print('API Error in submitAnswers: ${data["message"] ?? 'Unknown error'}');
          _showError(data['raw_points']);
        }
      } else {
        print('HTTP Error in submitAnswers: Status code ${response.statusCode}, Response: ${response.body}');
        _showError(null);
      }
    } catch (e) {
      print('Exception in submitAnswers: $e');
      _showError(null);
    }
  }

  void _showRewardModal(int rawPoints, int bonusPoints) {
    String rewardImage = '';
    String rewardName = '';

    switch (widget.antasId) {
      case 1:
        if (rawPoints >= 0 && rawPoints <= 10) {
          rewardImage = 'assets/taho.png';
          rewardName = 'Taho';
        } else if (rawPoints >= 11 && rawPoints <= 15) {
          rewardImage = 'assets/isaw.png';
          rewardName = 'Isaw';
        } else if (rawPoints >= 16 && rawPoints <= 19) {
          rewardImage = 'assets/lemur.png';
          rewardName = 'Lemur';
        } else if (rawPoints == 20) {
          rewardImage = 'assets/halo_halo.png';
          rewardName = 'Halo-Halo';
        }
        break;
      case 2:
        if (rawPoints >= 0 && rawPoints <= 9) {
          rewardImage = 'assets/isaw.png';
          rewardName = 'Isaw';
        } else if (rawPoints >= 10 && rawPoints <= 19) {
          rewardImage = 'assets/lemur.png';
          rewardName = 'Lemur';
        } else if (rawPoints == 20) {
          rewardImage = 'assets/halo_halo.png';
          rewardName = 'Halo-Halo';
        }
        break;
      case 3:
        if (rawPoints >= 0 && rawPoints <= 12) {
          rewardImage = 'assets/isaw.png';
          rewardName = 'Isaw';
        } else if (rawPoints >= 13 && rawPoints <= 24) {
          rewardImage = 'assets/kwek_kwek.png';
          rewardName = 'Kwek-Kwek';
        } else if (rawPoints == 25) {
          rewardImage = 'assets/halo_halo.png';
          rewardName = 'Halo-Halo';
        }
        break;
      case 4:
        if (rawPoints >= 0 && rawPoints <= 14) {
          rewardImage = 'assets/isaw.png';
          rewardName = 'Isaw';
        } else if (rawPoints >= 15 && rawPoints <= 29) {
          rewardImage = 'assets/kwek_kwek.png';
          rewardName = 'Kwek-Kwek';
        } else if (rawPoints == 30) {
          rewardImage = 'assets/halo_halo.png';
          rewardName = 'Halo-Halo';
        }
        break;
      default:
        rewardImage = 'assets/taho.png';
        rewardName = 'Taho';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rewardImage.isNotEmpty)
              Image.asset(
                rewardImage,
                height: 150,
                errorBuilder: (context, error, stackTrace) {
                  print('Image load error for $rewardImage: $error');
                  return const Icon(Icons.error, size: 150, color: Colors.red);
                },
              ),
            const SizedBox(height: 16),
            Text(
              "Nakatanggap ka ng $rewardName!",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.red[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Bonus Points: $bonusPoints",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              "OK",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(int? rawPoints) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents them from closing it by tapping outside
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Hindi Mo Nakamit",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.red[800],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add an icon for visual feedback
            Icon(Icons.menu_book_rounded, size: 80, color: Colors.orange[700]),
            const SizedBox(height: 16),
            Text(
              "Hindi mo nakamit ang puntos na kailangan upang makapasa. \n\nKailangan mong manood at tapusin ulit ang mga aralin bago makakuha muli ng pagsusulit.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[800],
              ),
            ),
            if (rawPoints != null) ...[
              const SizedBox(height: 16),
              Text(
                "Ang iyong puntos ay $rawPoints",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center, // Centers the button
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              Navigator.of(context).pop(); // Go back to the Aralin screen!
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Bumalik sa mga Aralin",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text(
            "Pagsusulit",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.red[700],
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[500]!, Colors.red[700]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
          elevation: 0,
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.red[700],
          ),
        ),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text(
            "Pagsusulit",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.red[700],
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[500]!, Colors.red[700]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
          elevation: 0,
        ),
        body: Center(
          child: Text(
            "No questions available",
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.grey[800],
            ),
          ),
        ),
      );
    }

    final question = questions[currentIndex];
    String instruction = '';
    switch (question['type']) {
      case 'multiple':
        instruction = 'Panuto: Pumili ng isang letra';
        break;
      case 'boolean':
        instruction = 'Panuto: Sagutin kung tama ba o mali';
        break;
      case 'identification':
        instruction = 'Panuto: Isulat ang wastong sagot sa bawat patlang';
        break;
      case 'jumbled':
        instruction = 'Panuto: Ayusin ang mga ginulong letra upang maibigay ang tamang kasagutan sa mga gabay na tanong';
        break;
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.red[700],
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red[500]!, Colors.red[700]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
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
            Text(
              'Pagsusulit',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _timeRemaining.inSeconds <= 60 ? Colors.yellow[700] : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '⏰ ${_formatDuration(_timeRemaining)}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _timeRemaining.inSeconds <= 60 ? Colors.black : Colors.red[700],
                ),
              ),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: Colors.grey[100],
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red[600]!, Colors.red[800]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      'Progreso',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (currentIndex + 1) / questions.length,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow[700]!),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${currentIndex + 1}/${questions.length}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
                      Text(
                        'Tanong ${currentIndex + 1} (${question['type'] == 'multiple' ? 'Multiple Choice - Easy' : question['type'] == 'boolean' ? 'True/False - Medium' : question['type'] == 'identification' ? 'Identification - Hard' : 'Jumbled Words - Hard'})',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.red[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        instruction,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        question['question'] ?? 'No question text',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: question['type'] == 'multiple' || question['type'] == 'boolean'
                            ? ListView(
                                children: question['choices']?.entries.map<Widget>((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: _buildAnswerOption(entry.key, entry.value),
                                  );
                                }).toList() ?? [],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    question['type'] == 'identification'
                                        ? 'Isulat ang tamang sagot:'
                                        : 'Ayusin ang mga salita upang mabuo ang tamang sagot:',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: textController,
                                    enabled: !showCorrection, // Disable typing while showing answer
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: showCorrection 
                                              ? (textController.text.trim().toLowerCase() == question['correct_answer'].toString().toLowerCase() ? Colors.green[700]! : Colors.red[700]!) 
                                              : Colors.grey[300]!
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: showCorrection 
                                              ? (textController.text.trim().toLowerCase() == question['correct_answer'].toString().toLowerCase() ? Colors.green[700]! : Colors.red[700]!) 
                                              : Colors.grey[300]!
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.red[700]!, width: 2),
                                      ),
                                      hintText: question['type'] == 'identification'
                                          ? 'Ilagay ang sagot'
                                          : 'Ilagay ang naayos na salita',
                                      filled: true,
                                      fillColor: showCorrection 
                                          ? (textController.text.trim().toLowerCase() == question['correct_answer'].toString().toLowerCase() ? Colors.green[50] : Colors.red[50]) 
                                          : Colors.grey[100],
                                    ),
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey[800],
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        userAnswers[currentIndex] = value;
                                      });
                                    },
                                  ),
                                  if (showCorrection && textController.text.trim().toLowerCase() != question['correct_answer'].toString().toLowerCase())
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12.0),
                                      child: Text(
                                        "Tamang Sagot: ${question['correct_answer']}",
                                        style: GoogleFonts.poppins(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          // Expanded(
                          //   child: ElevatedButton(
                          //     onPressed: currentIndex > 0 ? previousQuestion : null,
                          //     style: ElevatedButton.styleFrom(
                          //       backgroundColor: Colors.grey[300],
                          //       foregroundColor: Colors.grey[800],
                          //       padding: const EdgeInsets.symmetric(vertical: 16),
                          //       shape: RoundedRectangleBorder(
                          //         borderRadius: BorderRadius.circular(12),
                          //       ),
                          //       elevation: 2,
                          //     ),
                          //     child: Text(
                          //       "Bumalik",
                          //       style: GoogleFonts.poppins(
                          //         fontWeight: FontWeight.w600,
                          //         fontSize: 16,
                          //       ),
                          //     ),
                          //   ),
                          // ),
                          // const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                                onPressed: showCorrection // Check if currently showing answer
                                  ? null // Disable button during the 2-second pause
                                  : (question['type'] == 'multiple' || question['type'] == 'boolean')
                                      ? selectedAnswer != null
                                          ? nextQuestion
                                          : null
                                      : textController.text.trim().isNotEmpty
                                          ? nextQuestion
                                          : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                currentIndex < questions.length - 1 ? "Susunod" : "Tapusin",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildAnswerOption(String letter, String text) {
    final isSelected = selectedAnswer == letter;
    final correctAnswer = questions[currentIndex]['correct_answer'];
    final isCorrect = letter == correctAnswer;

    // Default colors
Color? bgColor = isSelected ? Colors.blue[50] : Colors.white;
    Color borderColor = isSelected ? Colors.blue[700]! : Colors.grey[300]!;
    Color gradientStart = isSelected ? Colors.blue[500]! : Colors.grey[400]!;
    Color gradientEnd = isSelected ? Colors.blue[700]! : Colors.grey[600]!;
    Color textColor = isSelected ? Colors.blue[800]! : Colors.grey[800]!;

    // Apply Green/Red if we are showing the correction (After clicking Susunod)
    if (showCorrection) {
      if (isCorrect) {
        bgColor = Colors.green[50];
        borderColor = Colors.green[700]!;
        gradientStart = Colors.green[500]!;
        gradientEnd = Colors.green[700]!;
        textColor = Colors.green[800]!;
      } else if (isSelected) {
        bgColor = Colors.red[50];
        borderColor = Colors.red[700]!;
        gradientStart = Colors.red[500]!;
        gradientEnd = Colors.red[700]!;
        textColor = Colors.red[800]!;
      }
    }

    return GestureDetector(
      onTap: showCorrection ? null : () { // Prevent tapping while checking answer
        setState(() {
          selectedAnswer = letter;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [gradientStart, gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: textColor,
                  fontWeight: isSelected || (showCorrection && isCorrect) ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}