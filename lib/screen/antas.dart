import 'dart:convert';
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
  int? completedLessonIndex = 0; // Initialize with Aralin 1 completed

  @override
  void initState() {
    super.initState();
    print('AntasPage loaded with id: ${widget.id}, aralinId: ${widget.aralinId}, sessionId: ${widget.sessionId}, antasId: ${widget.antasId}');
    fetchLessons();
  }

  Future<void> fetchLessons() async {
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
            
            // 1. Add this loop to auto-select the Aralin clicked from the Dashboard!
            if (lessons.isNotEmpty) {
              for (int i = 0; i < lessons.length; i++) {
                if (lessons[i]['id'].toString() == widget.aralinId.toString()) {
                  selectedLessonIndex = i;
                  completedLessonIndex = i; // Optional: Moves the green checkmark here too
                  break;
                }
              }
            }

            // Ensure completedLessonIndex is valid
            if (completedLessonIndex != null && completedLessonIndex! >= lessons.length) {
              completedLessonIndex = lessons.isNotEmpty ? 0 : null;
            }
          });
          print('Lessons fetched: ${lessons.length} lessons. Selected index: $selectedLessonIndex');
        } else {
          print('Fetch lessons failed: ${jsonData['message'] ?? 'No message'}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to fetch lessons: ${jsonData['message'] ?? 'Unknown error'}')),
            );
          }
        }
      } else {
        print('Fetch lessons failed with status: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error: HTTP ${response.statusCode}')),
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
            // Top Cards Section
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
                              aralinId: widget.aralinId,
                              sessionId: widget.sessionId,
                              antasId: widget.antasId,
                              // Use the selectedLessonIndex instead of always 0
                              lessonId: lessons.isNotEmpty ? lessons[selectedLessonIndex ?? 0]['id'] : 0, 
                            ),
                          ),
                        );
                        print('Navigating to LessonScreen for lesson index: ${selectedLessonIndex ?? 0}');
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
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuizScreen(
                              antasId: widget.antasId,
                              sessionId: widget.sessionId,
                              aralinId: widget.aralinId,
                            ),
                          ),
                        );
                        print('Navigating to QuizScreen');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF57C00),
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
                                Icons.quiz,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Pagsusulit',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'magpatakbo ng mga\npagsusulit at exam',
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
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Progress Section
            const Text(
              'Daloy ng Pag-aaral',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 16),

// Progress Items
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
                            bottom: index < (lessons.isNotEmpty ? lessons.length - 1 : 0) ? 12 : 0),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          // Magiging light red ang background kapag selected
                          color: isSelected ? const Color(0xFFD32F2F).withOpacity(0.08) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            // Magkakaroon ng red border kapag selected
                            color: isSelected ? const Color(0xFFD32F2F) : Colors.grey.shade300,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Circular Badge para sa Icon
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCompleted ? Icons.check_rounded : Icons.play_arrow_rounded,
                                color: isCompleted ? Colors.green[700] : Colors.grey[600],
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Text ng Aralin
                            Expanded(
                              child: Text(
                                lessons.isNotEmpty && index < lessons.length
                                    ? lessons[index]['title'] ?? 'Walang Pamagat'
                                    : 'Aralin ${index + 1}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? const Color(0xFFD32F2F) : Colors.black87,
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

            // Mga Paksa ng Aralin Section
            const Text(
              'Paksa at Buod ng Aralin',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 16),

            // Display selected lesson or first lesson by default
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
                          print('Navigating to LessonScreen for lesson index: $lessonIndex, lessonId: ${lessons[lessonIndex]['id']}');
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lessons[selectedLessonIndex ?? 0]['title'] ?? 'Walang Pamagat',
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
                                  ?.map((detail) => Text(
                                        '• $detail',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ))
                                  ?.toList() ??
                              [const Text('• Walang detalye.', style: TextStyle(color: Colors.white, fontSize: 14))],
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}