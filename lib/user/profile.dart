import 'dart:convert';
import 'dart:io';
import 'package:felamo/baseurl/baseurl.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as path;

class Profile extends StatefulWidget {
  final String sessionId;
  const Profile({super.key, required this.sessionId});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _lrnController = TextEditingController();
  final TextEditingController _birthdateController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _selectedGender = 'Lalaki';
  bool isSaving = false;
  File? _imageFile;
  String? _profileImageUrl;

  final String imageUploadUrl = '${baseUrl}update-profile-picture.php';
  final String profileFetchUrl = '${baseUrl}get-profile.php';

  @override
  void initState() {
    super.initState();
    print('SESSION ID from Profile: ${widget.sessionId}');
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    final uri = Uri.parse(profileFetchUrl);
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'session_id': widget.sessionId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final profileData = data['data'];
          setState(() {
            _firstNameController.text = profileData['first_name'] ?? '';
            _middleNameController.text = profileData['middle_name'] ?? '';
            _lastNameController.text = profileData['last_name'] ?? '';
            _lrnController.text = profileData['lrn'] ?? '';
            _birthdateController.text = _convertToDisplayFormat(profileData['birth_date']) ?? '';
            _emailController.text = profileData['email'] ?? '';
            _selectedGender = profileData['gender'] ?? 'Lalaki';
            _profileImageUrl = profileData['profile_picture'] != null
                ? 'https://darkslategrey-jay-754607.hostingersite.com/backend/storage/profile-pictures/${path.basename(profileData['profile_picture'])}'
                : null;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to fetch profile'), backgroundColor: Colors.red),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect to server'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('[EXCEPTION] fetchProfileData error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred'), backgroundColor: Colors.red),
      );
    }
  }

  String _convertToDisplayFormat(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    final parts = isoDate.split('-');
    if (parts.length == 3) {
      final day = parts[2].padLeft(2, '0');
      final month = parts[1].padLeft(2, '0');
      final year = parts[0];
      return '$day/$month/$year';
    }
    return '';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      _uploadProfilePicture();
    }
  }

  Future<void> _uploadProfilePicture() async {
    var request = http.MultipartRequest('POST', Uri.parse(imageUploadUrl));
    request.fields['session_id'] = widget.sessionId;
    request.files.add(await http.MultipartFile.fromPath('profile_picture', _imageFile!.path));

    var response = await request.send();
    if (response.statusCode == 200) {
      var resBody = await response.stream.bytesToString();
      final data = jsonDecode(resBody);

      if (data['status'] == 'success') {
        setState(() {
          _profileImageUrl = "https://darkslategrey-jay-754607.hostingersite.com/${data['profile_picture']}";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']), backgroundColor: Colors.green),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        isSaving = true;
      });

      final uri = Uri.parse('${baseUrl}edit-profile.php');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': widget.sessionId,
          'first_name': _firstNameController.text,
          'middle_name': _middleNameController.text,
          'last_name': _lastNameController.text,
          'lrn': _lrnController.text,
          'birth_date': _convertToIso(_birthdateController.text),
          'gender': _selectedGender,
          'email': _emailController.text,
        }),
      );

      setState(() {
        isSaving = false;
      });

      final data = jsonDecode(response.body);
      if (data['status'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Update failed'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _convertToIso(String date) {
    final parts = date.split('/');
    if (parts.length == 3) {
      final day = parts[0].padLeft(2, '0');
      final month = parts[1].padLeft(2, '0');
      final year = parts[2];
      return '$year-$month-$day';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF800000), Color(0xFFFFF8DC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              AppBar(
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
                title: Text(
                  'Personal na Impormasyon',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!)
                            : _profileImageUrl != null
                                ? Image.network(
                                    _profileImageUrl!,
                                  ).image
                                : const AssetImage('assets/profile.png'),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: MediaQuery.of(context).size.width * 0.35, // Adjusted for centering
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(label: 'First Name', controller: _firstNameController),
                      const SizedBox(height: 10),
                      _buildTextField(label: 'Middle Name', controller: _middleNameController),
                      const SizedBox(height: 10),
                      _buildTextField(label: 'Last Name', controller: _lastNameController),
                      const SizedBox(height: 10),
                      _buildTextField(label: 'LRN', controller: _lrnController, keyboardType: TextInputType.number),
                      const SizedBox(height: 10),
                      _buildTextField(
                        label: 'Birth Date',
                        controller: _birthdateController,
                        readOnly: true,
                        suffixIcon: const Icon(Icons.calendar_today),
                        onTap: () => _selectDate(context),
                      ),
                      const SizedBox(height: 10),
                      _buildGenderDropdown(),
                      const SizedBox(height: 10),
                      _buildTextField(label: 'Email', controller: _emailController, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 15),
                      Center(
                        child: ElevatedButton(
                          onPressed: isSaving ? null : _updateProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB71C1C),
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isSaving
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'SAVE CHANGES',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20), // Added padding at the bottom
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    bool readOnly = false,
    Widget? suffixIcon,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.leagueSpartan(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFB71C1C)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: suffixIcon,
          ),
          style: GoogleFonts.leagueSpartan(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w400,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'This field is required';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: GoogleFonts.leagueSpartan(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFB71C1C)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: ['Lalaki', 'Babae', 'Iba pa'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: GoogleFonts.leagueSpartan(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w400,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedGender = newValue!;
            });
          },
          validator: (value) => value == null ? 'Please select a gender' : null,
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005, 4, 11),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFFB71C1C)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthdateController.text =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _lrnController.dispose();
    _birthdateController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}