import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:softeng/data/profile_service.dart';
import 'navbar_assisted.dart'; // ✅ Import your shared navbar

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  String? _avatarUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ProfileService.fetchProfile(Supabase.instance.client);
      if (!mounted) return;
      setState(() {
        _avatarUrl = data?['avatar_url'] as String?;
      });
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    await _uploadAndSaveAvatar(image);
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

      final withBuster = '${result.publicUrl}?v=${DateTime.now().millisecondsSinceEpoch}';
      if (!mounted) return;
      setState(() => _avatarUrl = withBuster);
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
                    padding:
                        EdgeInsets.symmetric(horizontal: w * 0.05, vertical: h * 0.02),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF3D3D3D)),
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
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xFFF1D2B6),
                    backgroundImage:
                        _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                    child: _avatarUrl == null
                        ? const Icon(Icons.person, size: 70, color: Colors.white)
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
                        padding:
                            const EdgeInsets.symmetric(horizontal: 55, vertical: 14),
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

      /// ✅ Replaced repeated BottomNavigationBar
      bottomNavigationBar: const NavbarAssisted(currentIndex: 3),
    );
  }

  /// --- TEXT FIELD BUILDER ---
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black26),
            ),
          ),
        ),
      ],
    );
  }
}
