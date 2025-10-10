import 'package:flutter/material.dart';
import 'tasks_screen.dart';
import 'calendar_screen.dart';
import 'emergency_screen.dart';
import 'aboutpage.dart';
import 'legaldatapage.dart';
import 'settings.dart';
import 'help.dart';
import 'profile_page.dart';
import 'navbar_assisted.dart'; // ✅ Import the shared navbar

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EF),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),

              /// --- USER HEADER ---
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.brown[200],
                child: const Icon(Icons.person, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 10),
              const Text(
                'SHAWN URIEL\nCABUTIHAN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 1,
                ),
              ),

              /// --- GUARDIAN CARD ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 25),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2CC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.pinkAccent,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'GUARDIAN ID: 1919234',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'NERIAH VILLAPANA',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'EMAIL: nvilalpana@gmail.com',
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            'NUMBER: 09341243467',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              /// --- MENU BUTTONS ---
              _menuButton(Icons.person, 'PROFILE', const Color(0xFFB2EBF2),
                  onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              }),
              _menuButton(Icons.settings, 'SETTINGS', const Color(0xFFF8BBD0),
                  onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              }),
              _menuButton(Icons.info, 'ABOUT', const Color(0xFFFFE0B2),
                  onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutPage()),
                );
              }),
              _menuButton(Icons.help_outline, 'HELP & SUPPORT',
                  const Color(0xFFB3E5FC), onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const HelpSupportPage()),
                );
              }),
              _menuButton(Icons.policy, 'LEGAL & DATA', const Color(0xFFF8BBD0),
                  onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LegalDataPage()),
                );
              }),
            ],
          ),
        ),
      ),

      /// ✅ Use shared custom navbar
      bottomNavigationBar: const NavbarAssisted(currentIndex: 3),
    );
  }

  /// --- MENU BUTTON WIDGET ---
  static Widget _menuButton(IconData icon, String text, Color color,
      {VoidCallback? onTap}) {
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
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}
