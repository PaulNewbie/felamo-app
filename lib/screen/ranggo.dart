import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TalaNgRanggoScreen extends StatefulWidget {
  final String sessionId;
  const TalaNgRanggoScreen({super.key, required this.sessionId});

  @override
  State<TalaNgRanggoScreen> createState() => _TalaNgRanggoScreenState();
}

class _TalaNgRanggoScreenState extends State<TalaNgRanggoScreen> {
  final List<RankingItem> topThree = [];
  final List<RankingItem> otherRankings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchLeaderBoard();
  }

  Future<void> fetchLeaderBoard() async {
    final url = Uri.parse("https://darkslategrey-jay-754607.hostingersite.com/backend/api/app/get-overall-leader-boards.php");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"session_id": widget.sessionId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          List<RankingItem> rankings = (data['data'] as List)
              .map((item) => RankingItem(
                    name: item['first_name'] ?? '',
                    points: "${item['points'] ?? 0} Puntos",
                    rawPoints: item['points'] ?? 0,
                    rank: 0,
                  ))
              .toList();

          // Sort by points
          rankings.sort((a, b) => b.rawPoints.compareTo(a.rawPoints));

          // Assign ranks
          for (int i = 0; i < rankings.length; i++) {
            rankings[i] = rankings[i].copyWith(rank: i + 1);
          }

          setState(() {
            topThree.clear();
            otherRankings.clear();
            topThree.addAll(rankings.take(3));
            otherRankings.addAll(rankings.skip(3));
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB71C1C), Color(0xFF8B0000)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.arrow_back, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          const CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Tala ng Ranggo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Podium
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildPodiumCard(topThree.length > 1 ? topThree[1] : null, 2),
                          _buildPodiumCard(topThree.isNotEmpty ? topThree[0] : null, 1),
                          _buildPodiumCard(topThree.length > 2 ? topThree[2] : null, 3),
                        ],
                      ),
                    ),
                    
                    // List Container
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'Ranggo ng mga Mag-aaral',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: otherRankings.length,
                                itemBuilder: (context, index) {
                                  return _buildRankingListItem(otherRankings[index]);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Bottom Info Bar
                    Container(
                      color: const Color(0xFF38B6FF),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Iyong Ranggo: #5',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Patuloy sa pagkatuto upang umaangat pa.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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

  Widget _buildPodiumCard(RankingItem? item, int position) {
    IconData medalIcon;
    Color medalColor;
    const double cardHeight = 130; // Uniform height for all positions

    switch (position) {
      case 1:
        medalIcon = Icons.emoji_events;
        medalColor = Colors.amber;
        break;
      case 2:
        medalIcon = Icons.military_tech;
        medalColor = Colors.grey;
        break;
      case 3:
        medalIcon = Icons.workspace_premium;
        medalColor = Colors.brown;
        break;
      default:
        medalIcon = Icons.emoji_events;
        medalColor = Colors.amber;
    }

    return SizedBox(
      width: 85,
      child: Column(
        children: [
          Container(
            width: 85,
            height: cardHeight - 35,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: item == null
                ? const Center(child: Text("-", style: TextStyle(fontSize: 18, color: Colors.grey)))
                : Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(medalIcon, color: medalColor, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          item.name,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.points,
                          style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: medalColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$position',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingListItem(RankingItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.orange,
            radius: 20,
            child: Text(
              '${item.rank}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.points,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.star, color: Colors.orange, size: 24),
        ],
      ),
    );
  }
}

class RankingItem {
  final String name;
  final String points;
  final int rawPoints;
  final int rank;

  RankingItem({
    required this.name,
    required this.points,
    required this.rawPoints,
    required this.rank,
  });

  RankingItem copyWith({String? name, String? points, int? rawPoints, int? rank}) {
    return RankingItem(
      name: name ?? this.name,
      points: points ?? this.points,
      rawPoints: rawPoints ?? this.rawPoints,
      rank: rank ?? this.rank,
    );
  }
}