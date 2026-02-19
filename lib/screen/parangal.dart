import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MyWidget extends StatefulWidget {
  final String sessionId;
  const MyWidget({super.key, required this.sessionId});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  List<dynamic> _avatars = [];
  List<dynamic> _antasList = [];
  List<dynamic> _certificates = [];
  bool _isLoading = true;
  bool _isAntasLoading = true;
  bool _isCertificatesLoading = true;
  int? _equippedAvatarId;

  @override
  void initState() {
    super.initState();
    print('Initializing MyWidget with sessionId: ${widget.sessionId}');
    _fetchAvatars();
    _fetchAntas();
    _fetchCertificates();
  }

  Future<void> _fetchAvatars() async {
    const url = 'https://darkslategrey-jay-754607.hostingersite.com/backend/api/app/get-avatars.php';
    final body = jsonEncode({"session_id": widget.sessionId});

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      print('Avatars response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _avatars = data['data'] ?? [];
            _equippedAvatarId = _avatars.firstWhere(
              (avatar) => avatar['is_using'] == true,
              orElse: () => null,
            )?['id'];
            _isLoading = false;
          });
        } else {
          print('Avatars fetch failed: ${data['message']}');
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch avatars: ${data['message'] ?? 'Unknown error'}')),
          );
        }
      } else {
        print('Avatars fetch error: HTTP ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error fetching avatars: HTTP ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Avatars fetch exception: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching avatars: $e')),
      );
    }
  }

  Future<void> _fetchAntas() async {
    const url = 'https://darkslategrey-jay-754607.hostingersite.com/backend/api/app/get-antas.php';
    final body = jsonEncode({"session_id": widget.sessionId});

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      print('Antas response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _antasList = data['data'] ?? [];
            _isAntasLoading = false;
          });
        } else {
          print('Antas fetch failed: ${data['message']}');
          setState(() {
            _isAntasLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch antas: ${data['message'] ?? 'Unknown error'}')),
          );
        }
      } else {
        print('Antas fetch error: HTTP ${response.statusCode}');
        setState(() {
          _isAntasLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error fetching antas: HTTP ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Antas fetch exception: $e');
      setState(() {
        _isAntasLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching antas: $e')),
      );
    }
  }

  Future<void> _fetchCertificates() async {
    const url = 'https://darkslategrey-jay-754607.hostingersite.com/backend/api/app/get-certificates.php';
    final body = jsonEncode({"session_id": widget.sessionId});

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      print('Certificates response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _certificates = data['certificates'] ?? [];
            _isCertificatesLoading = false;
          });
          print('Certificates loaded: $_certificates');
        } else {
          print('Certificates fetch failed: ${data['message']}');
          setState(() {
            _isCertificatesLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch certificates: ${data['message'] ?? 'Unknown error'}')),
          );
        }
      } else {
        print('Certificates fetch error: HTTP ${response.statusCode}');
        setState(() {
          _isCertificatesLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error fetching certificates: HTTP ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Certificates fetch exception: $e');
      setState(() {
        _isCertificatesLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching certificates: $e')),
      );
    }
  }

  Future<void> _buyAvatar(int avatarId) async {
    const url = 'https://darkslategrey-jay-754607.hostingersite.com/backend/api/app/avail-avatar.php';
    final body = jsonEncode({
      "session_id": widget.sessionId,
      "avatar_id": avatarId
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Avatar purchased successfully')),
          );
          await _fetchAvatars();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to purchase avatar')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error purchasing avatar: HTTP ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error purchasing avatar: $e')),
      );
    }
  }

  Future<void> _equipAvatar(int avatarId) async {
    const url = 'https://darkslategrey-jay-754607.hostingersite.com/backend/api/app/update-avatar.php';
    final body = jsonEncode({
      "session_id": widget.sessionId,
      "avatar_id": avatarId
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Avatar equipped successfully')),
          );
          setState(() {
            _equippedAvatarId = avatarId;
          });
          await _fetchAvatars();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to equip avatar')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error equipping avatar: HTTP ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error equipping avatar: $e')),
      );
    }
  }

  void _showCertificateModal(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      print('Certificate image load error: $error');
                      return const Center(
                        child: Text(
                          'Failed to load certificate',
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade700,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red.shade700,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Mga Parangal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Sertipiko ng Antas'),
                      const SizedBox(height: 12),
                      _buildAntasList(),
                      const SizedBox(height: 20),
                      _buildSectionHeader('Espesyal na Gantimpala'),
                      const SizedBox(height: 12),
                      _buildRewardCard(
                        'Unang Hakbang',
                        'Kumpletuhin ang unang aralin',
                        Icons.star,
                        const Color(0xFF5271FF),
                        Colors.purple,
                        isCompleted: true,
                      ),
                      const SizedBox(height: 8),
                      _buildRewardCard(
                        'Modyul',
                        'Manood ng 10 araling bidyo',
                        Icons.book,
                        const Color(0xFF7ED957),
                        const Color(0xFF7ED957),
                        isCompleted: true,
                      ),
                      const SizedBox(height: 20),
                      _buildSectionHeader('Perpektong Iskor'),
                      const SizedBox(height: 12),
                      _buildRewardCard(
                        'Perpektong Iskor',
                        'Kumuhang 100% sa anumang pagsusulit',
                        Icons.adjust,
                        const Color(0xFFEF2525),
                        const Color(0xFFEF2525),
                        isCompleted: false,
                      ),
                      const SizedBox(height: 20),
                      _buildSectionHeader('Avatar Border'),
                      const SizedBox(height: 12),
                      _buildAvatarGrid(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildAntasList() {
    if (_isAntasLoading || _isCertificatesLoading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_antasList.isEmpty || _certificates.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: Text('No certificates available yet')),
      );
    }

    print('Antas List: $_antasList, Certificates: $_certificates');

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _antasList.length,
        itemBuilder: (context, index) {
          final antas = _antasList[index];
          final isDone = antas['is_done'] == true;
          final certificateId = antas['certificate_id']; // Optional backend field
          print('Index: $index, Certificate ID: $certificateId, Is Done: $isDone');
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildCertificateCard(
              antas['title'] ?? 'Walang Pamagat',
              isDone ? const Color(0xFF7ED957) : const Color(0xFFEDEDED),
              isDone ? Icons.military_tech : Icons.lock,
              isActive: isDone,
              certificateIndex: index,
              certificateId: certificateId,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCertificateCard(
    String title,
    Color color,
    IconData icon, {
    bool isActive = false,
    required int certificateIndex,
    String? certificateId,
  }) {
    return GestureDetector(
      onTap: isActive && _certificates.isNotEmpty && certificateIndex < _certificates.length
          ? () {
              final imageUrl = certificateId != null
                  ? 'https://darkslategrey-jay-754607.hostingersite.com/backend/storage/certs/$certificateId'
                  : 'https://darkslategrey-jay-754607.hostingersite.com/backend/storage/certs/${_certificates[certificateIndex]}';
              print('Showing certificate: $imageUrl');
              _showCertificateModal(imageUrl);
            }
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Certificate not available')),
              );
            },
      child: Container(
        width: 100,
        height: 80,
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.1) : const Color(0xFFEDEDED),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFF7ED957) : const Color(0xFFEDEDED),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF7ED957) : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.black87 : Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardCard(
    String title,
    String subtitle,
    IconData icon,
    Color bgColor,
    Color iconColor, {
    bool isCompleted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isCompleted ? Icons.check_circle : Icons.lock,
            color: isCompleted ? const Color(0xFF7ED957) : Colors.grey,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarGrid() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_avatars.isEmpty) {
      return const Center(
        child: Text('No avatars available'),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: _avatars.length,
      itemBuilder: (context, index) {
        final avatar = _avatars[index];
        final imageUrl = 'https://darkslategrey-jay-754607.hostingersite.com/backend/storage/assets/${avatar['filename']}';
        return _buildAvatarItem(imageUrl, avatar['owned'] == true, avatar['price'], avatar['id']);
      },
    );
  }

  Widget _buildAvatarItem(String imageUrl, bool isOwned, String price, int avatarId) {
    return GestureDetector(
      onTap: isOwned
          ? () => _equipAvatar(avatarId)
          : () => _showBuyDialog(avatarId, price),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _equippedAvatarId == avatarId ? Colors.green : Colors.grey.shade300,
            width: _equippedAvatarId == avatarId ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  color: Colors.grey.shade50,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        colorBlendMode: isOwned ? null : BlendMode.saturation,
                        color: isOwned ? null : Colors.grey.withOpacity(0.7),
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.person, size: 30, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                    if (!isOwned)
                      const Icon(
                        Icons.lock,
                        color: Colors.white,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isOwned ? Colors.green.shade100 : Colors.grey.shade200,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Center(
                child: Text(
                  isOwned ? 'Owned' : '$price Puntos',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: isOwned ? Colors.green.shade800 : Colors.grey.shade800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBuyDialog(int avatarId, String price) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Buy Avatar'),
          content: Text('Do you want to purchase this avatar for $price Puntos?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _buyAvatar(avatarId);
              },
              child: const Text('Buy'),
            ),
          ],
        );
      },
    );
  }
}