import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:softeng/data/profile_service.dart';
import 'navbar_assisted.dart'; // ✅ shared navbar

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  String? _avatarUrl;
  bool _saving = false;
  Timer? _nameSaveDebounce;

  // ✏️ edit states
  bool _isEditingName = false;
  bool _isEditingBirthday = false;

  // ✅ controllers initialized at declaration (hot-reload safe)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  // store ISO (YYYY-MM-DD) for DB save
  String? _birthdayIso;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
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
    try {
      final client = Supabase.instance.client;
      final data = await ProfileService.fetchProfile(client);
      if (!mounted) return;

      _nameController.text = (data?['fullname'] as String?) ?? '';
      _emailController.text = (data?['email'] as String?) ?? '';

      // birthday: convert stored text (possibly ISO) -> readable UI + keep ISO for saving
      final raw = (data?['birthday'] as String?) ?? '';
      final parsed = _tryParseIsoDate(raw);
      if (parsed != null) {
        _birthdayIso = _toIso(parsed);
        _birthdayController.text = _toReadable(parsed);
      } else {
        _birthdayIso = null;
        _birthdayController.text = '';
      }

      final rawUrl = data?['avatar_url'] as String?;
      setState(() {
        _avatarUrl = (rawUrl == null || rawUrl.trim().isEmpty)
            ? null
            : '$rawUrl?v=${DateTime.now().millisecondsSinceEpoch}';
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
      setState(() => _avatarUrl = withBuster);
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

  // ---- Birthday helpers ----
  static DateTime? _tryParseIsoDate(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    try {
      return DateTime.parse(s); // handles YYYY-MM-DD or full ISO
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
    DateTime initial = DateTime(1970, 1, 1);
    final parsed = _tryParseIsoDate(_birthdayIso ?? _birthdayController.text);
    if (parsed != null) initial = parsed;

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
      _birthdayIso = _toIso(picked); // store ISO for DB
      _birthdayController.text = _toReadable(picked); // show readable in UI
      setState(() {}); // refresh styles if needed
    }
  }

  // (No bottom nav handlers required on this page)

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

              // Avatar
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xFFF1D2B6),
                    backgroundImage: _avatarUrl != null
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: _avatarUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 70,
                            color: Colors.white,
                          )
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

              // Show birthday under the avatar/title if assigned
              if (_birthdayController.text.trim().isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _birthdayController.text.trim(),
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Fields
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  children: [
                    _buildEditableField(
                      label: 'NAME',
                      controller: _nameController,
                      isEditing: _isEditingName,
                      onEditToggle: () {
                        setState(() => _isEditingName = !_isEditingName);
                      },
                      onChanged: _onNameChanged,
                    ),
                    const SizedBox(height: 15),

                    // Email: read-only, same white style
                    _buildReadOnlyField(
                      label: 'EMAIL',
                      controller: _emailController,
                    ),
                    const SizedBox(height: 15),

                    // 🎂 Birthday: calendar opens on first tap (field or icon)
                    _buildBirthdayField(
                      label: 'BIRTHDAY',
                      controller: _birthdayController,
                      isEditing: _isEditingBirthday,
                      onEditToggle: () {
                        setState(
                          () => _isEditingBirthday = !_isEditingBirthday,
                        );
                      },
                      onPickDate: () {
                        // Ensure gray "editing" style is shown, then open picker
                        if (!_isEditingBirthday) {
                          setState(() => _isEditingBirthday = true);
                        }
                        _pickBirthday();
                      },
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
                            email: _emailController.text.trim().isEmpty
                                ? null
                                : _emailController.text.trim(),
                            // Save ISO string (YYYY-MM-DD). Works fine with TEXT column.
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

      // ✅ Assisted navbar
      bottomNavigationBar: const NavbarAssisted(currentIndex: 3),
    );
  }

  // ---------------- helpers ----------------

  // read-only field (email) — white like others
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

  // editable field with gray edit icon inside; text turns gray while editing
  Widget _buildEditableField({
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

  // Birthday: field opens calendar on first tap (field or icon)
  Widget _buildBirthdayField({
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onEditToggle,
    required VoidCallback onPickDate,
  }) {
    void _openPickerNow() {
      if (!isEditing) onEditToggle(); // show gray "editing" state
      onPickDate(); // open date picker immediately
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
          onTap: _openPickerNow, // tap anywhere in the field
          child: AbsorbPointer(
            absorbing: true, // prevent keyboard
            child: TextField(
              controller: controller,
              readOnly: true,
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
                  onPressed: _openPickerNow, // icon also opens picker now
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
}
