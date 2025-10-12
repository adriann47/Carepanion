import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:softeng/data/profile_service.dart';
import 'tasks_screen_regular.dart';
import 'calendar_screen_regular.dart';
import 'companion_list.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final int _currentIndex = 3;
  File? _profileImage; // ✅ Store selected image
  String? _avatarUrl; // ✅ Remote avatar from Supabase
  bool _saving = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final client = Supabase.instance.client;
    try {
      final data = await ProfileService.fetchProfile(client);
      if (!mounted) return;
      setState(() {
        _avatarUrl = (data?['avatar_url'] as String?)?.trim().isEmpty == true
            ? null
            : data?['avatar_url'] as String?;
      });
    } catch (_) {
      // Silently ignore; UI will show placeholder
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (mounted) {
        setState(() {
          _profileImage = File(image.path);
        });
      }

      // Also upload to Supabase and persist URL
      await _uploadAndSaveAvatar(image);
    }
  }

  Future<void> _uploadAndSaveAvatar(XFile image) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to update avatar.')),
      );
      return;
    }

    try {
      if (mounted) setState(() => _saving = true);

      // Read bytes and derive extension
      final Uint8List bytes = await image.readAsBytes();
      final String ext = image.path.split('.').last.toLowerCase();

      final result = await ProfileService.uploadAvatar(
        client,
        bytes: bytes,
        fileExt: ext,
        userId: user.id,
      );

      await ProfileService.updateAvatarUrl(
        client,
        userId: user.id,
        avatarUrl: result.publicUrl,
      );

      // Bust caches by appending a version param
      final withBuster = '${result.publicUrl}?v=${DateTime.now().millisecondsSinceEpoch}';
      if (!mounted) return;
      setState(() {
        _avatarUrl = withBuster;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update avatar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onTabTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TasksScreenRegular()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CalendarScreenRegular()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CompanionListScreen()),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfilePage()), // Fixed
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EF),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 🔹 Pink Header
              Container(
                width: double.infinity,
                height: h * 0.18,
                decoration: const BoxDecoration(
                  color: Color(0xFFF7A9AC),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: w * 0.05,
                      vertical: h * 0.02,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF3D3D3D),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "PROFILE",
                          style: GoogleFonts.nunito(
                            fontSize: w * 0.07,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF3D3D3D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),
              Text(
                'EDIT PROFILE',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: 1,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 18),

              // 🖼️ Editable Profile Picture
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xFFF1D2B6),
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : (_avatarUrl != null ? NetworkImage(_avatarUrl!) : null) as ImageProvider<Object>?,
                    child: _profileImage == null
                        ? (_avatarUrl == null
                            ? const Icon(
                                Icons.person,
                                size: 70,
                                color: Colors.white,
                              )
                            : null)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.pinkAccent,
                          shape: BoxShape.circle,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 18,
                              ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // 📝 Profile Form Fields
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  children: [
                    _buildTextField('NAME', 'SHAWN URIEL CABUTIHAN'),
                    const SizedBox(height: 15),
                    _buildTextField('EMAIL', 'SHAWNURIEL@GMAIL.COM'),
                    const SizedBox(height: 15),
                    _buildTextField('BIRTHDAY', 'JUNE 1, 1956'),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF7A9AC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 55,
                          vertical: 14,
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'SAVE CHANGES',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),

      // 🔹 Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.pink,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: [
          _navItem(Icons.home, 'Home', isSelected: _currentIndex == 0),
          _navItem(
            Icons.calendar_today,
            'Calendar',
            isSelected: _currentIndex == 1,
          ),
          _navItem(
            Icons.family_restroom,
            'Alert',
            isSelected: _currentIndex == 2,
          ),
          _navItem(
            Icons.notifications,
            'Notifications',
            isSelected: _currentIndex == 3,
          ),
          _navItem(Icons.person, 'Profile', isSelected: _currentIndex == 4),
        ],
      ),
    );
  }

  // 🧱 Text Field Builder
  Widget _buildTextField(String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.nunito(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black26),
            ),
          ),
        ),
      ],
    );
  }

  /// 🧭 Helper for nav bar icon styling
  static BottomNavigationBarItem _navItem(
    IconData icon,
    String label, {
    bool isSelected = false,
  }) {
    return BottomNavigationBarItem(
      label: label,
      icon: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? Colors.pink.shade100 : const Color(0xFFE0E0E0),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 28,
            color: isSelected ? Colors.pink : Colors.black87,
          ),
        ),
      ),
    );
  }
}
