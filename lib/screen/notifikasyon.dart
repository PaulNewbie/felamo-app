import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:timeago/timeago.dart' as timeago;

class Notifikasyon extends StatefulWidget {
  final String sessionid;

  const Notifikasyon({super.key, required this.sessionid});

  @override
  State<Notifikasyon> createState() => _NotifikasyonState();
}

class _NotifikasyonState extends State<Notifikasyon> {
  List<dynamic> _notifications = [];
  bool isLoading = true;

  // Define colors for different notification types
  final List<Color> _cardColors = [
    Color(0xFFFFB3BA), // Light pink
    Color(0xFFBAF7BA), // Light green
    Color(0xFFBAD3FF), // Light blue
    Color(0xFFFFE4B5), // Light orange
    Color(0xFFE0BBE4), // Light purple
  ];

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    final url = Uri.parse("https://darkslategrey-jay-754607.hostingersite.com/backend/api/app/get-student-notification.php");

    try {
      print("Sending session_id: ${widget.sessionid}"); // 🔍 print session id

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"}, // Set JSON content type
        body: jsonEncode({"session_id": widget.sessionid}), // Encode as JSON
      );

      print("Status Code: ${response.statusCode}"); // 🔍 print status code
      print("Response: ${response.body}"); // 🔍 print full response

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        print("Decoded Response: $body");

        if (body["status"] == "success" && body["data"] != null) {
          setState(() {
            _notifications = body["data"];
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
          print("Failed: ${body["message"] ?? "Unknown error"}");
        }
      } else {
        setState(() {
          isLoading = false;
        });
        print("HTTP Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print("Error fetching notifications: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFEF2525), // Your specified red color
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  // --- ADDED BACK BUTTON HERE ---
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  // ------------------------------
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Notipikasyon',
                    style: GoogleFonts.leagueSpartan(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _notifications.isEmpty
                        ? Center(
                            child: Text(
                              "Walang notipikasyon",
                              style: GoogleFonts.leagueSpartan(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: _notifications.length,
                            itemBuilder: (context, index) {
                              final notif = _notifications[index];
                              
                              // --- TIMEZONE FIX ---
                              String timeString = notif["created_at"];
                              // If the server string doesn't have a timezone marker, append 'Z' to treat it as UTC
                              if (!timeString.endsWith("Z")) {
                                timeString += "Z";
                              }
                              // Parse as UTC and convert to the user's local device time (UTC+8)
                              final createdAt = DateTime.parse(timeString).toLocal();
                              // --------------------
                              
                              final timeAgo = timeago.format(createdAt, locale: 'en_short');

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: _buildNotificationCard(
                                  title: notif["title"],
                                  message: notif["description"],
                                  timeAgo: timeAgo,
                                  backgroundColor: _cardColors[index % _cardColors.length],
                                  index: index,
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required String title,
    required String message,
    required String timeAgo,
    required Color backgroundColor,
    required int index,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.leagueSpartan(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                timeAgo,
                style: GoogleFonts.leagueSpartan(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          // Description
          Text(
            message,
            style: GoogleFonts.leagueSpartan(
              fontSize: 14,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}