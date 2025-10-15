import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:softeng/data/profile_service.dart';
import 'package:softeng/data/multi_guardian_service.dart';
import 'aboutpage.dart';
import 'legaldatapage.dart';
import 'settings.dart';
import 'help.dart';
import 'profile_page.dart';
import 'navbar_assisted.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _avatarUrl;
  String? _fullName; // ✅ user name
  // Support multiple guardians
  List<Map<String, dynamic>> _guardianProfiles = [];
  bool _loadingGuardians = false;
  RealtimeChannel? _agChannel;
  RealtimeChannel? _profileChannel;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _subscribeRealtime();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ProfileService.fetchProfile(Supabase.instance.client);
      if (!mounted) return;

      // ✅ Extract user info
      setState(() {
        _avatarUrl = data?['avatar_url'] as String?;
        _fullName = (data?['fullname'] ??
                '${data?['first_name'] ?? ''} ${data?['last_name'] ?? ''}')
            .trim();
      });
      // Load all guardians (join table + legacy guardian_id)
      await _loadGuardians();
    } catch (_) {}
  }

  void _subscribeRealtime() {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    // Join table changes
    _agChannel?.unsubscribe();
    _agChannel = client
        .channel('public:assisted_guardians:profile')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'assisted_guardians',
        callback: (payload) {
          final newRec = payload.newRecord as Map<String, dynamic>?;
          if (newRec?['assisted_id']?.toString() == uid) {
            _loadGuardians();
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'assisted_guardians',
        callback: (payload) {
          final oldRec = payload.oldRecord as Map<String, dynamic>?;
          if (oldRec?['assisted_id']?.toString() == uid) {
            _loadGuardians();
          }
        },
      )
      ..subscribe();

    // Legacy profile.guardian_id updates for current assisted
    _profileChannel?.unsubscribe();
    _profileChannel = client
        .channel('public:profile_guardian:profile')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'profile',
        callback: (payload) {
          final newRec = payload.newRecord as Map<String, dynamic>?;
          if (newRec?['id']?.toString() == uid) {
            _loadGuardians();
          }
        },
      )
      ..subscribe();
  }

  Future<void> _loadGuardians() async {
    setState(() => _loadingGuardians = true);
    try {
      final rows = await MultiGuardianService.listGuardians(
        Supabase.instance.client,
      );
      if (!mounted) return;
      setState(() => _guardianProfiles = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardianProfiles = []);
    } finally {
      if (mounted) setState(() => _loadingGuardians = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFFF8F4EF);
    const Color guardianCardColor = Color(0xFFFFF3C0);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),

              /// --- USER HEADER ---
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.brown[300],
                backgroundImage:
                    _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                child: _avatarUrl == null
                    ? const Icon(Icons.person, size: 56, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 12),

              /// ✅ Dynamic user name (first + last)
              Text(
                _fullName?.isNotEmpty == true ? _fullName! : 'Loading...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 22),

              /// --- GUARDIAN CARDS (multiple) ---
              if (_loadingGuardians)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(),
                ),
              if (!_loadingGuardians && _guardianProfiles.isEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 25),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: guardianCardColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.person_off, size: 28, color: Colors.black54),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No guardian linked',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_guardianProfiles.isNotEmpty)
                ..._guardianProfiles.map((g) => _guardianCard(g, guardianCardColor)),

              const SizedBox(height: 30),

              /// --- MENU BUTTONS ---
              _menuButton(
                icon: Icons.person,
                text: 'PROFILE',
                color: const Color(0xFFB2EBF2),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfilePage()),
                  );
                },
              ),
              _menuButton(
                icon: Icons.settings,
                text: 'SETTINGS',
                color: const Color(0xFFF8BBD0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsScreen()),
                  );
                },
              ),
              _menuButton(
                icon: Icons.info,
                text: 'ABOUT',
                color: const Color(0xFFFFE0B2),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AboutPage()),
                  );
                },
              ),
              _menuButton(
                icon: Icons.help_outline,
                text: 'HELP & SUPPORT',
                color: const Color(0xFFB3E5FC),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const HelpSupportPage()),
                  );
                },
              ),
              _menuButton(
                icon: Icons.policy,
                text: 'LEGAL & DATA',
                color: const Color(0xFFF8BBD0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LegalDataPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const NavbarAssisted(currentIndex: 3),
    );
  }

  /// Single guardian card widget replicating the existing style
  Widget _guardianCard(Map<String, dynamic> g, Color guardianCardColor) {
    final publicId = (g['public_id'] ?? '').toString();
    final fullname = (g['fullname'] ?? '').toString();
    final email = (g['email'] ?? '').toString();
    // avatar_url may not be present in listGuardians; show placeholder
    final String? avatarUrl = g['avatar_url'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: guardianCardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.pinkAccent,
            backgroundImage:
                avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 30)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GUARDIAN ID: $publicId',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fullname,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'EMAIL: $email',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _agChannel?.unsubscribe();
    _profileChannel?.unsubscribe();
    super.dispose();
  }

  /// --- MENU BUTTON WIDGET ---
  static Widget _menuButton({
    required IconData icon,
    required String text,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.black54, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18),
          ],
        ),
      ),
    );
  }
}
