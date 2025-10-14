import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:softeng/Regular%20Screen/notification_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:softeng/data/profile_service.dart';
import 'tasks_screen_regular.dart';
import 'calendar_screen_regular.dart';
import 'companion_list.dart';
// import 'notification_regular.dart'; // unused

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final int _currentIndex = 4;
  File? _profileImage;
  String? _avatarUrl;
  bool _saving = false;
  Timer? _nameSaveDebounce;

  final ImagePicker _picker = ImagePicker();

  // Edit state
  bool _isEditingName = false;
  bool _isEditingBirthday = false;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  // We’ll store an ISO (YYYY-MM-DD) version here for saving to DB
  String? _birthdayIso;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameSaveDebounce?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    _nameSaveDebounce?.cancel();
    _nameSaveDebounce = Timer(const Duration(milliseconds: 500), () async {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      final fullName = value.trim();
      try {
        await ProfileService.upsertProfile(
          client,
          id: user.id,
          fullName: fullName.isEmpty ? null : fullName,
        );
      } catch (_) {}
    });
  }

  Future<void> _loadProfile() async {
    final client = Supabase.instance.client;
    try {
      final data = await ProfileService.fetchProfile(client);
      if (!mounted) return;

      // Populate
      _nameController.text = (data?['fullname'] as String?) ?? '';
      _emailController.text = (data?['email'] as String?) ?? '';

      final rawBirthday = (data?['birthday'] as String?) ?? '';
      final parsed = _tryParseIsoDate(rawBirthday);
      if (parsed != null) {
        _birthdayIso = _toIso(parsed);
        _birthdayController.text = _toReadable(parsed);
      } else {
        // if not a valid iso date, leave as is (or empty)
        _birthdayIso = null;
        _birthdayController.text = '';
      }

      setState(() {
        _avatarUrl = (data?['avatar_url'] as String?)?.trim().isEmpty == true
            ? null
            : data?['avatar_url'] as String?;
      });
    } catch (_) {
      // ignore silently
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
      await _uploadAndSaveAvatar(image);
    }
  }

  Future<void> _uploadAndSaveAvatar(XFile image) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be signed in to update avatar.'),
        ),
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

      final withBuster =
          '${result.publicUrl}?v=${DateTime.now().millisecondsSinceEpoch}';
      if (!mounted) return;
      setState(() {
        _avatarUrl = withBuster;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile picture updated.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update avatar: $e')));
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
        MaterialPageRoute(builder: (context) => NotificationScreen(notifications: const [])),
      );
    }
  }

  // ---- Birthday helpers ----
  static DateTime? _tryParseIsoDate(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    try {
      // Accepts YYYY-MM-DD (recommended), or full ISO strings
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  static String _toIso(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static const _months = [
    '', // 1-based
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _toReadable(DateTime d) {
    return '${_months[d.month]} ${d.day}, ${d.year}';
  }

  Future<void> _pickBirthday() async {
    // Decide initial date for the picker
    DateTime initial = DateTime(1970, 1, 1);
    final parsed = _tryParseIsoDate(_birthdayIso ?? _birthdayController.text);
    if (parsed != null) initial = parsed;

    // Bounds: 1900..today
    final today = DateTime.now();
    final first = DateTime(1900, 1, 1);
    final last = DateTime(today.year, today.month, today.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) || initial.isAfter(last)
          ? DateTime(1970, 1, 1)
          : initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Select Birthday',
    );

    if (picked != null) {
      _birthdayIso = _toIso(picked);
      _birthdayController.text = _toReadable(picked);
      setState(() {}); // refresh styles if needed
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
              // Header
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

              // Profile Picture
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xFFF1D2B6),
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : (_avatarUrl != null
                                  ? NetworkImage(_avatarUrl!)
                                  : null)
                              as ImageProvider<Object>?,
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
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

              // Fields
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  children: [
                    _buildEditableTextField(
                      label: 'NAME',
                      controller: _nameController,
                      isEditing: _isEditingName,
                      onEditToggle: () {
                        setState(() => _isEditingName = !_isEditingName);
                      },
                      onChanged: _onNameChanged,
                    ),
                    const SizedBox(height: 15),
                    _buildReadOnlyField(
                      label: 'EMAIL',
                      controller: _emailController,
                    ),
                    const SizedBox(height: 15),

                    // 🎂 Birthday: uses a date picker
                    _buildBirthdayField(
                      label: 'BIRTHDAY',
                      controller: _birthdayController,
                      isEditing: _isEditingBirthday,
                      onEditToggle: () {
                        setState(
                          () => _isEditingBirthday = !_isEditingBirthday,
                        );
                        // optional: open picker immediately when entering edit mode
                        // if (_isEditingBirthday) _pickBirthday();
                      },
                      onPickDate: _pickBirthday,
                    ),

                    const SizedBox(height: 30),

                    ElevatedButton(
                      onPressed: () async {
                        final client = Supabase.instance.client;
                        final user = client.auth.currentUser;
                        if (user == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('You must be signed in.'),
                            ),
                          );
                          return;
                        }
                        try {
                          await ProfileService.upsertProfile(
                            client,
                            id: user.id,
                            fullName: _nameController.text.trim().isEmpty
                                ? null
                                : _nameController.text.trim(),
                            // Keep email in sync if you store it in profile
                            email: _emailController.text.trim().isEmpty
                                ? null
                                : _emailController.text.trim(),
                            // Save ISO string (YYYY-MM-DD). Works for text *and* date columns.
                            birthday: _birthdayIso,
                          );
                          if (!mounted) return;
                          setState(() {
                            _isEditingName = false;
                            _isEditingBirthday = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Changes saved')),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to save: $e')),
                          );
                        }
                      },
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

      // Bottom Navigation Bar
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

  // ----- Field builders -----

  // Read-only field (email) — white like others
  Widget _buildReadOnlyField({
    required String label,
    required TextEditingController controller,
  }) {
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
          controller: controller,
          readOnly: true,
          style: GoogleFonts.nunito(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
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

  // Name (editable text with gray edit icon inside)
  Widget _buildEditableTextField({
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onEditToggle,
    void Function(String)? onChanged,
  }) {
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
          controller: controller,
          readOnly: !isEditing,
          onChanged: onChanged,
          style: GoogleFonts.nunito(
            color: isEditing ? Colors.grey[600] : Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
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
            suffixIcon: IconButton(
              onPressed: onEditToggle,
              icon: Icon(Icons.edit, color: Colors.grey[600], size: 20),
              tooltip: isEditing ? 'Stop editing' : 'Edit',
            ),
          ),
        ),
      ],
    );
  }

  // Birthday (calendar picker)
  Widget _buildBirthdayField({
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onEditToggle,
    required VoidCallback onPickDate,
  }) {
    void _openPickerNow() {
      // ensure the UI shows “editing” gray state immediately
      if (!isEditing) onEditToggle();
      onPickDate();
    }

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
        GestureDetector(
          // ✅ open calendar on first tap (no edit-gating)
          onTap: _openPickerNow,
          child: AbsorbPointer(
            absorbing: true, // keep keyboard from appearing
            child: TextField(
              controller: controller,
              readOnly: true, // always read-only; we pick via calendar
              style: GoogleFonts.nunito(
                color: isEditing
                    ? Colors.grey[600]
                    : Colors.black87, // gray while “editing”
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
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
                // ✅ icon also opens calendar immediately
                suffixIcon: IconButton(
                  onPressed: _openPickerNow,
                  icon: Icon(
                    Icons.calendar_today,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  tooltip: 'Pick date',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // nav helper
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
