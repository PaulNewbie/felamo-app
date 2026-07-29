import 'package:felamo/screen/about.dart';
import 'package:felamo/screen/parangal.dart';
import 'package:felamo/screen/ranggo.dart';
import 'package:felamo/user/login.dart';
import 'package:felamo/user/profile.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:io';
import 'dart:convert';
import 'package:felamo/baseurl/baseurl.dart';
import 'package:felamo/screen/activity_board.dart';

import 'package:felamo/services/font_scale_controller.dart';

class SettingsScreen extends StatefulWidget {
  final String sessionId;
  final String email;
  final String firstName;

  const SettingsScreen({
    super.key,
    required this.sessionId,
    required this.email,
    required this.firstName,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEffectsEnabled = true;
  // bool _darkModeEnabled = false;

  void _showChangePasswordModal() {
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Palitan ang Password',
            style: GoogleFonts.leagueSpartan(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Kasalukuyang Password',
                    labelStyle: GoogleFonts.leagueSpartan(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Bagong Password',
                    labelStyle: GoogleFonts.leagueSpartan(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                print('Change password modal closed');
              },
              child: Text(
                'Kanselahin',
                style: GoogleFonts.leagueSpartan(color: Colors.red),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final currentPassword = currentPasswordController.text;
                final newPassword = newPasswordController.text;

                if (currentPassword.isEmpty || newPassword.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Punan ang lahat ng field.',
                        style: GoogleFonts.leagueSpartan(),
                      ),
                    ),
                  );
                  return;
                }

                final url = Uri.parse('$baseUrl/change-password.php');
                print('Changing password: $url, sessionId=${widget.sessionId}');
                try {
                  final httpClient = HttpClient()
                    ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
                  final client = IOClient(httpClient);
                  final response = await client.post(
                    url,
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({
                      "session_id": widget.sessionId,
                      "password": currentPassword,
                      "new_password": newPassword,
                    }),
                  ).timeout(const Duration(seconds: 30), onTimeout: () {
                    throw Exception('Request timed out. Please check your network.');
                  });

                  print('Change password response status: ${response.statusCode}');
                  print('Change password response body: ${response.body}');

                  if (response.statusCode == 200) {
                    final jsonData = jsonDecode(response.body);
                    if (jsonData['status'] == 200) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            jsonData['message'] ?? 'Password updated successfully.',
                            style: GoogleFonts.leagueSpartan(),
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                      print('Password updated successfully');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            jsonData['message'] ?? 'Failed to update password.',
                            style: GoogleFonts.leagueSpartan(),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      print('Change password failed: ${jsonData['message'] ?? 'No message'}');
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Server error: HTTP ${response.statusCode}',
                          style: GoogleFonts.leagueSpartan(),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    print('Change password failed with status: ${response.statusCode}');
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Network error: $e',
                        style: GoogleFonts.leagueSpartan(),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  print('Change password error: $e');
                }
              },
              child: Text(
                'Palitan',
                style: GoogleFonts.leagueSpartan(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFontSizeModal() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Sukat ng Font',
                style: GoogleFonts.leagueSpartan(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: AppFontSize.values.map((size) {
                  final isSelected = fontScaleController.fontSize == size;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        await fontScaleController.setFontSize(size);
                        setModalState(() {});
                        setState(() {}); // refresh the label shown in settings row
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF330006).withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF330006) : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle : Icons.circle_outlined,
                              color: isSelected ? const Color(0xFF330006) : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              size.label,
                              style: GoogleFonts.leagueSpartan(
                                fontSize: 16 * size.scale, // live preview of the size
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Isara', style: GoogleFonts.leagueSpartan(color: const Color(0xFF330006))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF330006),
      appBar: AppBar(
        backgroundColor: const Color(0xFF330006),
        elevation: 0,
        title: Text(
          'Mga Setting',
          style: GoogleFonts.leagueSpartan(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFFFFFF),
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Color(0xFFD4A574),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(20),
              width: MediaQuery.of(context).size.width * 0.9,
              decoration: BoxDecoration(
                color: const Color(0xFFE9DFC7),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => Profile(sessionId: widget.sessionId)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF330006).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.person, color: Colors.white, size: 30),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.firstName,
                                  style: GoogleFonts.leagueSpartan(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Ranggo #5 - 2050 puntos',
                                  style: GoogleFonts.leagueSpartan(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  widget.email,
                                  style: GoogleFonts.leagueSpartan(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSettingsOption(
                    icon: Icons.history_rounded,
                    title: 'Talaan ng Aktibidad',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActivityBoardScreen(
                            sessionId: widget.sessionId,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildSettingsOptionWithSwitch(
                    icon: Icons.notifications,
                    title: 'Notipikasyon',
                    value: _notificationsEnabled,
                    onChanged: (value) => setState(() => _notificationsEnabled = value),
                  ),
                  _buildSettingsOptionWithSwitch(
                    icon: Icons.volume_up,
                    title: 'Mga Sound Effect',
                    value: _soundEffectsEnabled,
                    onChanged: (value) => setState(() => _soundEffectsEnabled = value),
                  ),
                  // _buildSettingsOptionWithSwitch(
                  //   icon: Icons.dark_mode,
                  //   title: 'Dark Mode',
                  //   value: _darkModeEnabled,
                  //   onChanged: (value) => setState(() => _darkModeEnabled = value),
                  // ),

                  _buildSettingsOption(
                    icon: Icons.text_fields,
                    title: 'Sukat ng Font (${fontScaleController.fontSize.label})',
                    onTap: _showFontSizeModal,
                  ),

                  _buildSettingsOption(
                    icon: Icons.brush,
                    title: 'Avatar Border',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MyWidget(sessionId: widget.sessionId)),
                      );
                    },
                  ),
                  _buildSettingsOption(
                    icon: Icons.info,
                    title: 'About',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => About()),
                      );
                    },
                  ),
                  _buildSettingsOption(
                    icon: Icons.lock,
                    title: 'Palitan ang Password',
                    onTap: _showChangePasswordModal,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF330006),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const Login()),
                          (Route<dynamic> route) => false, // Clears everything from the previous session
                        );
                      },
                      child: Text(
                        'Mag Log-Out',
                        style: GoogleFonts.leagueSpartan(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getIconBackgroundColor(icon),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(
        title,
        style: GoogleFonts.leagueSpartan(
          color: Colors.black,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.black54),
      onTap: onTap,
    );
  }

  Widget _buildSettingsOptionWithSwitch({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getIconBackgroundColor(icon),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(
        title,
        style: GoogleFonts.leagueSpartan(
          color: Colors.black,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.green,
      ),
    );
  }

  Color _getIconBackgroundColor(IconData icon) {
    return const Color(0xFF330006);
  }
}