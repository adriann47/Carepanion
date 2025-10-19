import 'package:flutter/material.dart';
import 'tasks_screen_regular.dart';
import 'calendar_screen_regular.dart';
import 'notification_screen.dart';
import 'companion_list.dart';
import 'profile_screen_regular.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  int _currentIndex = 4; // Profile index (Help page comes from profile)

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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CompanionListScreen()),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => NotificationScreen(notifications: const []),
        ),
      );
    } else if (index == 4) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    }
  }

  /// --- SHOW FAQ POPUP ---
  void _showFaqDialog(String question, List<String> answers) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 25,
            vertical: 40,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 18),
                ...answers.map(
                  (answer) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "• ",
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                        Expanded(
                          child: Text(
                            answer,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Align(
                  alignment: Alignment.center,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF80DEEA),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 35,
                        vertical: 14,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "OK",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
              padding: const EdgeInsets.fromLTRB(24, 50, 24, 30),
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
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "HELP & SUPPORT",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 35),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "FAQ",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 35),
                children: [
                  GestureDetector(
                    onTap: () => _showFaqDialog(
                      "HOW TO CONNECT TO A GUARDIAN/ASSISTED USER ?",
                      [
                        "Enter the user ID (name of the user) to connect with the guardian or assisted user. Then, tap Submit to send the request.",
                        "Go to account settings, press add a guardian and input their user name or email to add them.",
                      ],
                    ),
                    child: const _FaqQuestion(
                      "HOW TO CONNECT TO A GUARDIAN/ASSISTED USER ?",
                    ),
                  ),
                  const Divider(thickness: 1, color: Colors.black26),
                  GestureDetector(
                    onTap: () => _showFaqDialog(
                      "HOW CAN I VIEW ALL OF MY COMPANIONS?",
                      [
                        "To view all companions, use the navigation bar below and tap the icon with the people symbol. This will take you to a page where you can see a list of all your companions.",
                      ],
                    ),
                    child: const _FaqQuestion(
                      "HOW CAN I VIEW ALL OF MY COMPANIONS?",
                    ),
                  ),
                  const Divider(thickness: 1, color: Colors.black26),
                  GestureDetector(
                    onTap: () => _showFaqDialog(
                      "HOW TO CHANGE ACCOUNT DETAILS?",
                      [
                        "To change your account details, tap the profile icon in the bottom corner, then click Profile. From there, you can edit your account information such as your name, birthday, email, and more.",
                      ],
                    ),
                    child: const _FaqQuestion("HOW TO CHANGE ACCOUNT DETAILS?"),
                  ),
                  const Divider(thickness: 1, color: Colors.black26),
                  GestureDetector(
                    onTap: () => _showFaqDialog(
                      "HOW TO CONTACT CUSTOMER SERVICE?",
                      [
                        "With customer service, you can contact us by going to your profile and clicking About. You will find our contact number and official address there.",
                        "If you would like to report a bug, share a concern, or provide feedback, go to the profile icon, then select Settings, where you will see options to report a bug or send feedback.",
                      ],
                    ),
                    child: const _FaqQuestion(
                      "HOW TO CONTACT CUSTOMER SERVICE?",
                    ),
                  ),
                  const Divider(thickness: 1, color: Colors.black26),
                ],
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
            size: 26,
            color: isSelected ? Colors.pink : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _FaqQuestion extends StatelessWidget {
  final String text;
  const _FaqQuestion(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        textAlign: TextAlign.left,
      ),
    );
  }
}
