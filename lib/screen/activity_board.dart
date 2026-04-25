import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../baseurl/baseurl.dart';

class ActivityBoardScreen extends StatefulWidget {
  final String sessionId;
  const ActivityBoardScreen({Key? key, required this.sessionId})
      : super(key: key);

  @override
  State<ActivityBoardScreen> createState() => _ActivityBoardScreenState();
}

class _ActivityBoardScreenState extends State<ActivityBoardScreen> {
  List<dynamic> _activities = [];
  bool _isLoading = true;

  // Summary counters
  int _loginCount   = 0;
  int _videoCount   = 0;
  int _quizCount    = 0;
  int _totalPoints  = 0;

  @override
  void initState() {
    super.initState();
    _fetchActivities();
  }

  Future<void> _fetchActivities() async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}get-student-activity.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'session_id': widget.sessionId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final list = List<dynamic>.from(data['data']);

          // Compute summary
          int logins = 0, videos = 0, quizzes = 0, pts = 0;
          for (var item in list) {
            final type = item['activity_type'];
            final p    = int.tryParse(item['points_earned'].toString()) ?? 0;
            pts += p;
            if (type == 'login')  logins++;
            if (type == 'video')  videos++;
            if (type == 'quiz')   quizzes++;
          }

          if (mounted) {
            setState(() {
              _activities   = list;
              _loginCount   = logins;
              _videoCount   = videos;
              _quizCount    = quizzes;
              _totalPoints  = pts;
              _isLoading    = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Map<String, dynamic> _typeConfig(String type) {
    switch (type) {
      case 'login':
        return {
          'icon':  Icons.login_rounded,
          'color': const Color(0xFF1976D2),
          'bg':    const Color(0xFFE3F2FD),
          'label': 'Login',
        };
      case 'video':
        return {
          'icon':  Icons.play_circle_fill,
          'color': const Color(0xFF388E3C),
          'bg':    const Color(0xFFE8F5E9),
          'label': 'Video',
        };
      case 'quiz':
        return {
          'icon':  Icons.quiz_rounded,
          'color': const Color(0xFFF57C00),
          'bg':    const Color(0xFFFFF3E0),
          'label': 'Quiz',
        };
      default:
        return {
          'icon':  Icons.star,
          'color': Colors.grey,
          'bg':    Colors.grey[100]!,
          'label': type,
        };
    }
  }

  String _formatDate(String rawDate) {
    try {
      // Treat as UTC then convert to local
      final dt = DateTime.parse(
        rawDate.endsWith('Z') ? rawDate : rawDate + 'Z'
      ).toLocal();
      final months = [
        '', 'Enero', 'Pebrero', 'Marso', 'Abril', 'Mayo', 'Hunyo',
        'Hulyo', 'Agosto', 'Setyembre', 'Oktubre', 'Nobyembre', 'Disyembre'
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return rawDate;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
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
        title: Text(
          'Talaan ng Aktibidad',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)))
          : Column(
              children: [
                _buildSummaryBar(),
                Expanded(
                  child: _activities.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: const Color(0xFFB71C1C),
                          onRefresh: _fetchActivities,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: _activities.length,
                            itemBuilder: (context, index) =>
                                _buildActivityCard(_activities[index], index),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      color: const Color(0xFFB71C1C),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Row(
        children: [
          _summaryChip(Icons.login_rounded,       '$_loginCount',  'Logins'),
          const SizedBox(width: 8),
          _summaryChip(Icons.play_circle_fill,    '$_videoCount',  'Videos'),
          const SizedBox(width: 8),
          _summaryChip(Icons.quiz_rounded,        '$_quizCount',   'Quizzes'),
          const SizedBox(width: 8),
          _summaryChip(Icons.star_rounded,        '$_totalPoints', 'Puntos'),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text(label,
                style: GoogleFonts.poppins(
                    color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(dynamic item, int index) {
    final type   = item['activity_type'] as String;
    final config = _typeConfig(type);
    final pts    = int.tryParse(item['points_earned'].toString()) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Row(
        children: [
          // Colored left strip
          Container(
            width: 5,
            height: 72,
            decoration: BoxDecoration(
              color: config['color'] as Color,
              borderRadius: const BorderRadius.only(
                topLeft:    Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),

          // Icon bubble
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: config['bg'] as Color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              config['icon'] as IconData,
              color: config['color'] as Color,
              size: 22,
            ),
          ),

          // Text content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['activity_label'] as String,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: config['color'] as Color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['activity_detail'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(item['activity_date'] as String),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Points badge
          if (pts > 0)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Text(
                '+$pts',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.orange[800],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Wala pang aktibidad.',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Magsimulang matuto para makita ang iyong kasaysayan dito.',
            style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}