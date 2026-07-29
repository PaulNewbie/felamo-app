import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../baseurl/baseurl.dart';

class QuizHistoryScreen extends StatefulWidget {
  final String sessionId;
  final int aralinId;

  const QuizHistoryScreen({
    Key? key,
    required this.sessionId,
    required this.aralinId,
  }) : super(key: key);

  @override
  State<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends State<QuizHistoryScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _historyData;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
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
            _historyData = data['status'] == 'success' ? data : null;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _resolveAnswerDisplay(Map<String, dynamic> item) {
    final type = item['type'] as String;
    final raw = item['student_answer'].toString();

    if (type == 'multiple_choice') {
      final choices = Map<String, dynamic>.from(item['choices'] ?? {});
      return choices[raw.toUpperCase()] ?? raw;
    }
    if (type == 'true_false') {
      return raw == '1' ? 'Fact' : 'Bluff';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9DFC7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF330006),
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Color(0xFF330006),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'Kasaysayan ng Pagsusulit',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF330006)))
          : _historyData == null
              ? Center(
                  child: Text(
                    'Walang kasaysayan na nahanap.',
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                  ),
                )
              : _buildHistory(),
    );
  }

  Widget _buildHistory() {
    final score = _historyData!['score'] as int;
    final total = _historyData!['total'] as int;
    final answers = List<Map<String, dynamic>>.from(_historyData!['answers']);
    final pct = total > 0 ? ((score / total) * 100).round() : 0;

    return Column(
      children: [
        // Score header
        Container(
          width: double.infinity,
          color: const Color(0xFF330006),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            children: [
              Text(
                '$score / $total',
                style: GoogleFonts.poppins(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '$pct% — Pumasa',
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
              ),
            ],
          ),
        ),

        // Answer list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: answers.length,
            itemBuilder: (context, index) {
              final item = answers[index];
              final answerText = _resolveAnswerDisplay(item);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question number + type badge — neutral colours only
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEEEE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Tanong ${index + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF330006),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF4e0506)),
                          ),
                          child: Text(
                            _typeLabel(item['type']),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF4e0506),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Question text
                    Text(
                      item['question_text'] ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Student's answer — neutral styling, no correctness implied
                    Row(
                      children: [
                        Icon(Icons.edit_note_rounded,
                            size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Text(
                          'Iyong sagot: ',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            answerText,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF330006),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'multiple_choice':
        return 'Multiple Choice';
      case 'true_false':
        return 'Fact o Bluff';
      case 'identification':
        return 'Pagpapakilala';
      case 'jumbled_word':
        return 'Mga Salita';
      default:
        return type;
    }
  }
}