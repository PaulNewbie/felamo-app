
import 'dart:async';
import 'dart:convert';
import 'package:felamo/baseurl/baseurl.dart';
import 'package:felamo/models/antas_model.dart';
import 'package:felamo/screen/antas.dart';
import 'package:felamo/screen/video.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:io';
import 'package:felamo/screen/bottombar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

class Dashboard extends StatefulWidget {
  final String firstName;
  final String sessionid;
  final int pointsReceived;
  final int currentStreak;
  final int id;
  final String email;

  const Dashboard({
    super.key,
    required this.firstName,
    required this.sessionid,
    required this.pointsReceived,
    required this.currentStreak,
    required this.id,
    required this.email,
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<Antas> antasList = [];
  int _currentIndex = 0;
  int _progressPercentage = 0;
  String? _lrn;
  int? _points;
  String? _profilePicture;
  String? _avatarFileName;

  @override
  void initState() {
    super.initState();
    print('Dashboard Initialized: sessionId=${widget.sessionid}, id=${widget.id}, firstName=${widget.firstName}');
    fetchAntas();
    fetchProgressPercentage();
    fetchProfile();

    _checkAndShowStreakModal();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkAndShowStreakModal() async {
    // 1. Prevent showing if the user received 0 points
    if (widget.pointsReceived <= 0) {
      return; 
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Create a unique key for the user so it works correctly if different accounts log in
    String key = 'last_streak_modal_date_${widget.id}';
    String lastDateStr = prefs.getString(key) ?? '';
    
    DateTime now = DateTime.now();
    // Format the current date as YYYY-MM-DD
    String todayStr = '${now.year}-${now.month}-${now.day}';

    // 2. Check if the modal has already been shown today
    if (lastDateStr != todayStr) {
      // Show the modal
      Future.delayed(Duration.zero, () {
        if (mounted) {
          _showCustomStreakModal();
        }
      });
      
      // Update the stored date in SharedPreferences
      await prefs.setString(key, todayStr);
    }
  }

  Future<void> fetchProfile() async {
    final url = Uri.parse('$baseUrl/get-profile.php');
    print('Fetching profile: $url, sessionId=${widget.sessionid}');
    try {
      final httpClient = HttpClient()..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      final client = IOClient(httpClient);
      final response = await client.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"session_id": widget.sessionid}),
      ).timeout(const Duration(seconds: 30), onTimeout: () {
        throw Exception('Request timed out. Please check your network.');
      });

      print('Profile response status: ${response.statusCode}');
      print('Profile response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success' && jsonData['data'] != null) {
          setState(() {
            _lrn = jsonData['data']['lrn'] as String?;
            _points = jsonData['data']['points'] as int?;
            _profilePicture = jsonData['data']['profile_picture'] as String?;
            _avatarFileName = jsonData['data']['avatar_file_name'] as String? ?? 'default_avatar.webp';
          });
          print('Profile fetched: LRN=$_lrn, Points=$_points, ProfilePicture=$_profilePicture, Avatar=$_avatarFileName');
        } else {
          print('Fetch profile failed: ${jsonData['message'] ?? 'No message'}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error fetching profile: ${jsonData['message'] ?? 'Unknown error'}')),
            );
          }
        }
      } else {
        print('Fetch profile failed with status: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error: HTTP ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      print('Fetch profile error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
        );
      }
    }
  }

  Future<void> fetchProgressPercentage() async {
    final url = Uri.parse('$baseUrl/get-level-percentage.php');
    print('Fetching progress percentage: $url, sessionId=${widget.sessionid}');
    try {
      final httpClient = HttpClient()..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      final client = IOClient(httpClient);
      final response = await client.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"session_id": widget.sessionid}),
      ).timeout(const Duration(seconds: 30), onTimeout: () {
        throw Exception('Request timed out. Please check your network.');
      });

      print('Progress response status: ${response.statusCode}');
      print('Progress response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success' && jsonData['percentage'] != null) {
          setState(() {
            _progressPercentage = jsonData['percentage'] as int;
          });
          print('Progress percentage updated: $_progressPercentage%');
        } else {
          print('Fetch progress failed: ${jsonData['message'] ?? 'No message'}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error fetching progress: ${jsonData['message'] ?? 'Unknown error'}')),
            );
          }
        }
      } else {
        print('Fetch progress failed with status: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error: HTTP ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      print('Fetch progress error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
        );
      }
    }
  }

  Future<void> fetchAntas() async {
    final url = Uri.parse('$baseUrl/get-antas.php');
    print('Fetching antas: $url, sessionId=${widget.sessionid}');
    try {
      final httpClient = HttpClient()..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      final client = IOClient(httpClient);
      final response = await client.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"session_id": widget.sessionid}),
      ).timeout(const Duration(seconds: 30), onTimeout: () {
        throw Exception('Request timed out. Please check your network.');
      });

      print('Antas response status: ${response.statusCode}');
      print('Antas response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success' && jsonData['data'] != null) {
          final List<dynamic> data = jsonData['data'];
          final List<Antas> fetchedAntas = data.map((e) => Antas.fromJson(e)).toList();
          setState(() {
            antasList = fetchedAntas;
          });
          print('Antas fetched: ${antasList.length} levels');
        } else {
          print('Fetch antas failed: ${jsonData['message'] ?? 'No message'}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error fetching levels: ${jsonData['message'] ?? 'Unknown error'}')),
            );
          }
        }
      } else {
        print('Fetch antas failed with status: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error: HTTP ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      print('Fetch antas error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
        );
      }
    }
  }

  void _showCustomStreakModal() {
    print('Showing streak modal with pointsReceived=${widget.pointsReceived}, currentStreak=${widget.currentStreak}');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20, top: 12),
                      child: Text(
                        'Streak na pag Log-in',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        print('Streak modal closed');
                      },
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Image.asset(
                    'assets/taho.png',
                    width: 100,
                    height: 100,
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading taho.png: $error');
                      return Icon(Icons.error, size: 100, color: Colors.red);
                    },
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Nakatanggap ka ng Taho!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  '+${widget.pointsReceived} Puntos',
                  style: TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Progreso ng Streak: ${widget.currentStreak}/7 Araw',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 15,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey[300],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: (widget.currentStreak * 100) ~/ 7,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: LinearGradient(
                                    colors: [Colors.blue[200]!, Colors.blue[600]!, Colors.blue[900]!],
                                    stops: [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 100 - (widget.currentStreak * 100) ~/ 7,
                              child: Container(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Kumpletuhin ang ', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          Text('7 araw', style: TextStyle(fontSize: 10, color: Colors.orange.shade600, fontWeight: FontWeight.w600)),
                          Text(' para makakuha ng Halo-halo! ', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onBottomNavTap(int index) {
    setState(() => _currentIndex = index);
    print('Bottom nav tapped: index=$index');
    switch (index) {
      case 1:
        Navigator.pushNamed(context, '/lessons');
        break;
      case 2:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF800000), Color(0xFFFFF8DC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(),
                _buildProgressCard(),
                _buildLevelList(),
                SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.transparent),
        child: CustomBottomBar(
          currentIndex: _currentIndex,
          onTap: _onBottomNavTap,
          firstName: widget.firstName,
          sessionId: widget.sessionid,
          pointsReceived: widget.pointsReceived,
          current_streak: widget.currentStreak,
          id: widget.id,
          points: _points ?? 0,
          email: widget.email,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Stack keeps the Frame directly on top of the Profile Picture
          Stack(
            alignment: Alignment.center,
            children: [
              // 1. Profile Picture (Inner Circle) - Size 80x80
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.white, width: 2),
                  image: DecorationImage(
                    image: _profilePicture != null && _profilePicture!.isNotEmpty
                        ? Image.network(
                            'https://darkslategrey-jay-754607.hostingersite.com/backend/storage/profile-pictures/${path.basename(_profilePicture!)}',
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading profile picture: $error');
                              return Image.asset('assets/profile.png');
                            },
                          ).image
                        : const AssetImage('assets/profile.png') as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              
              // 2. Avatar/Frame (Outer Layer) - Size 110x110
              // This renders directly over the profile picture
              Container(
                width: 110, // Slightly larger than 80 to act as a border/frame
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(55),
                  image: DecorationImage(
                    image: _avatarFileName != null && _avatarFileName!.isNotEmpty
                        ? Image.network(
                            'https://darkslategrey-jay-754607.hostingersite.com/backend/storage/assets/$_avatarFileName',
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading avatar frame: $error');
                              return Image.asset('assets/default_avatar.png');
                            },
                          ).image
                        : const AssetImage('assets/default_avatar.png') as ImageProvider,
                    // Note: Depending on your frame's transparent padding, you might 
                    // need to change this to BoxFit.contain instead of BoxFit.cover
                    fit: BoxFit.cover, 
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 16),

          // 3. User Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kumusta, ${widget.firstName}!',
                  style: GoogleFonts.leagueSpartan(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'LRN: ${_lrn ?? 'Loading...'}',
                  style: GoogleFonts.leagueSpartan(fontSize: 14, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Kabuuang Puntos: ${_points ?? 'Loading...'}',
                  style: GoogleFonts.leagueSpartan(fontSize: 14, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progreso sa Pag-aaral',
                style: GoogleFonts.leagueSpartan(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              SizedBox(width: 10),
              Text(
                '$_progressPercentage% Kumpleto',
                style: GoogleFonts.leagueSpartan(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey[300],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: _progressPercentage,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: [Colors.blue[400]!, Colors.yellow[300]!, Colors.pink[200]!],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                Expanded(flex: 100 - _progressPercentage, child: Container()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Simulan ang Pag-aaral',
            style: GoogleFonts.leagueSpartan(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 8),
          Text(
            'Tapusin muna ang unang markahaUn upang ma-unlock ang mga susunod na aralin.',
            style: GoogleFonts.leagueSpartan(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          antasList.isEmpty
              ? Center(
                  child: Text(
                    'Walang available na antas.',
                    style: GoogleFonts.leagueSpartan(fontSize: 14, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: antasList.length,
                  itemBuilder: (context, index) {
                    final antas = antasList[index];
                    return _buildLevelCard(
                      antas: antas,
                      color: _getColorForLevel(antas.level),
                      icon: _getIconForLevel(antas.level),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildLevelCard({required Antas antas, required Color color, required IconData icon}) {
    final isUnlocked = antas.level == 1 || (antasList.indexWhere((a) => a.level == antas.level - 1) >= 0 && antasList[antasList.indexWhere((a) => a.level == antas.level - 1)].is_done);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: Offset(0, 2))],
        gradient: !isUnlocked
            ? LinearGradient(
                colors: [color.withOpacity(0.3), color.withOpacity(0.6)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                antas.title,
                style: GoogleFonts.leagueSpartan(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(isUnlocked ? icon : Icons.lock, color: Colors.white, size: 24),
            ],
          ),
          const SizedBox(height: 8),
          antas.aralins.isEmpty
              ? Text(
                  'No Aralin available',
                  style: GoogleFonts.leagueSpartan(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                )
              : Column(
                  children: antas.aralins.asMap().entries.map((entry) {
                    final index = entry.key;
                    final aralin = entry.value;
                    return GestureDetector(
                      onTap: () {
                        if (isUnlocked) {
                          print('Navigating to AntasPage: antasId=${antas.id}, sessionId=${widget.sessionid}, aralinId=${aralin.id}');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AntasPage(
                                id: antas.level,
                                sessionId: widget.sessionid,
                                antasId: antas.id,
                                aralinId: aralin.id,
                              ),
                            ),
                          );
                        } else {
                          print('Level ${antas.level} is locked');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Level ${antas.level} is locked')),
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Aralin ${index + 1}: ${aralin.title}',
                                    style: GoogleFonts.leagueSpartan(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Video: ${aralin.attachment_filename.isNotEmpty ? aralin.attachment_filename : 'No Video'}',
                                    style: GoogleFonts.leagueSpartan(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isUnlocked ? Icons.play_circle_outline : Icons.lock,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Color _getColorForLevel(int level) {
    switch (level) {
      case 1:
        return const Color(0xFF4CAF50);
      case 2:
        return const Color(0xFF2196F3);
      case 3:
        return const Color(0xFFFFC107);
      case 4:
        return const Color(0xFFF44336);
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForLevel(int level) {
    switch (level) {
      case 1:
        return Icons.play_arrow;
      case 2:
        return Icons.trending_up;
      case 3:
        return Icons.star;
      case 4:
        return Icons.lock;
      default:
        return Icons.help_outline;
    }
  }
}
