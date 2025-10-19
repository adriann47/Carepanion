import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:softeng/data/profile_service.dart';
import 'tasks_screen_regular.dart';
import 'calendar_screen_regular.dart';
import 'aboutpage_regular.dart';
import 'legaldatapage_regular.dart';
import 'settings_regular.dart';
import 'help_regular.dart';
import 'notification_screen.dart';
import 'profile_page.dart';
import 'companion_list.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _currentIndex = 4;
  String? _avatarUrl;
  String? _fullName;
  String? _phone;
  String? _birthday;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final client = Supabase.instance.client;
      final authUser = client.auth.currentUser;

      final data = await ProfileService.fetchProfile(client);
      if (!mounted) return;

      final fullname = (data?['fullname'] as String?)?.trim();
      final friendlyFromEmail = () {
        final email = authUser?.email ?? '';
        if (email.contains('@')) {
          final local = email.split('@').first;
          final parts = local
              .split(RegExp(r'[._\s]+'))
              .where((s) => s.isNotEmpty);
          return parts
              .map((p) => p[0].toUpperCase() + p.substring(1))
              .join(' ');
        }
        return email;
      }();

      setState(() {
        _fullName = (fullname != null && fullname.isNotEmpty)
            ? fullname
            : friendlyFromEmail;
        final raw = data?['avatar_url'] as String?;
        _avatarUrl = (raw == null || raw.trim().isEmpty)
            ? null
            : '$raw?v=${DateTime.now().millisecondsSinceEpoch}';
        _phone = ProfileService.readPhoneFrom(data);
        _birthday = ProfileService.readBirthdayFrom(data);
      });
    } catch (_) {
      // ignore
    }
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;

    setState(() => _currentIndex = index);

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
        MaterialPageRoute(builder: (context) => NotificationScreen()),
      );
    } else if (index == 4) {
      // Already on Profile
    }
  }

  @override
  Widget build(BuildContext context) {
    final nameText = (_fullName == null || _fullName!.trim().isEmpty)
        ? '—'
        : _fullName!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F4EF),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // --- USER HEADER ---
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.brown[200],
                backgroundImage: _avatarUrl != null
                    ? NetworkImage(_avatarUrl!)
                    : null,
                child: _avatarUrl == null
                    ? const Icon(Icons.person, size: 50, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 10),

              Text(
                nameText,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 0.5,
                ),
              ),

              if ((_birthday ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _birthday!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              if ((_phone ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _phone!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 25),

              // --- MENU BUTTONS ---
              _menuButton(
                Icons.person,
                'PROFILE',
                const Color(0xFFB2EBF2),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfilePage(),
                    ),
                  );
                  if (mounted) _loadProfile();
                },
              ),
              _menuButton(
                Icons.settings,
                'SETTINGS',
                const Color(0xFFF8BBD0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              _menuButton(
                Icons.info,
                'ABOUT',
                const Color(0xFFFFE0B2),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AboutPage()),
                  );
                },
              ),
              _menuButton(
                Icons.help_outline,
                'HELP & SUPPORT',
                const Color(0xFFB3E5FC),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HelpSupportPage(),
                    ),
                  );
                },
              ),
              _menuButton(
                Icons.policy,
                'LEGAL & DATA',
                const Color(0xFFF8BBD0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LegalDataPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),

      // --- 5-BUTTON NAVBAR ---
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

  // --- MENU BUTTON ---
  static Widget _menuButton(
    IconData icon,
    String text,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.black54),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

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
