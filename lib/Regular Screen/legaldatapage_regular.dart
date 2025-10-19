import 'package:flutter/material.dart';
import 'tasks_screen_regular.dart';
import 'calendar_screen_regular.dart';
import 'notification_screen.dart';
import 'companion_list.dart';
import 'profile_screen_regular.dart';

class LegalDataPage extends StatefulWidget {
  const LegalDataPage({super.key});

  @override
  State<LegalDataPage> createState() => _LegalDataPageState();
}

class _LegalDataPageState extends State<LegalDataPage> {
  int _currentIndex = 4; // Profile tab highlighted

  void _onTabTapped(int index) {
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
      // Alert → Notification Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => CompanionListScreen()),
      );
    } else if (index == 3) {
      // Notifications (if you have a separate notification screen)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => NotificationScreen()),
      );
    } else if (index == 4) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF9F4),
      body: SafeArea(
        child: Column(
          children: [
            /// --- TOP HEADER ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 50, 24, 50),
              decoration: const BoxDecoration(
                color: Color(0xFFFFB6B6),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Back button
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.black87,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "LEGAL AND DATA",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 35),

            /// --- MAIN CONTENT ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      "assets/nameLogo.jpg",
                      width: 200,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      "Carepanion values your privacy and security. All personal information, reminders, and activity logs are stored securely and are only accessible to you and your chosen guardians. We do not share or sell your data to third parties. You remain in full control of your account, with the option to update, export, or permanently delete your information at any time, in accordance with our Privacy Policy and Terms of Service.",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      /// --- 5-BUTTON NAVBAR ---
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
            'Companions',
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

  /// --- NAVBAR ITEM WITH PINK HIGHLIGHT WHEN SELECTED ---
  static BottomNavigationBarItem _navItem(
    IconData icon,
    String label, {
    required bool isSelected,
  }) {
    return BottomNavigationBarItem(
      label: label,
      icon: Container(
        width: 60,
        height: 60,
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
