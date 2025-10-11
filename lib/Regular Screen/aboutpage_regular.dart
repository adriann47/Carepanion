import 'package:flutter/material.dart';
import 'package:softeng/Regular%20Screen/notification_screen.dart';
import 'tasks_screen_regular.dart';
import 'calendar_screen_regular.dart';
import 'profile_screen_regular.dart';
import 'companion_list.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  int _currentIndex = 4; // Profile tab highlighted by default

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
            /// --- TOP PINK HEADER ---
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
                            builder: (context) => const ProfileScreen()),
                      );
                    },
                    child: const Icon(Icons.arrow_back,
                        color: Colors.black87, size: 28),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "ABOUT",
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
                    // Logo image
                    Image.asset(
                      "assets/nameLogo.jpg",
                      width: 200,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 35),

                    // Description
                    const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: "Carepanion ",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              fontSize: 18,
                            ),
                          ),
                          TextSpan(
                            text:
                                "is a mobile app designed to make daily routines easier, healthier, and more consistent by providing smart reminders, spoken notifications, progress tracking, and an emergency help feature. Whether you’re a Guardian supporting loved ones, a Companion receiving simple guidance, or a Regular User managing personal goals, Carepanion is here to keep you organized, safe, and motivated every day.",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.black87,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.justify,
                    ),

                    const Spacer(),

                    /// Contact Us
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "CONTACT US",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    Row(
                      children: const [
                        Icon(Icons.email, color: Colors.black87, size: 24),
                        SizedBox(width: 12),
                        Text(
                          "CAREPANION@GMAIL.COM",
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: const [
                        Icon(Icons.phone, color: Colors.black87, size: 24),
                        SizedBox(width: 12),
                        Text(
                          "63+ 918 123 6789",
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      /// --- 5-BUTTON NAV BAR ---
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
          _navItem(Icons.calendar_today, 'Calendar',
              isSelected: _currentIndex == 1),
          _navItem(Icons.family_restroom, 'Alert',
              isSelected: _currentIndex == 2),
          _navItem(Icons.notifications, 'Notifications',
              isSelected: _currentIndex == 3),
          _navItem(Icons.person, 'Profile', isSelected: _currentIndex == 4),
        ],
      ),
    );
  }

  /// --- NAV ITEM STYLING ---
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
          color:
              isSelected ? Colors.pink.shade100 : const Color(0xFFE0E0E0),
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
