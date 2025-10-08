import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tasks_screen_regular.dart';
import 'calendar_screen_regular.dart';
import 'companion_list.dart';
import 'notification_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _currentIndex = 3;

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
              CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFFF1D2B6),
                child: const Icon(Icons.person, size: 70, color: Colors.white),
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
          _navItem(Icons.calendar_today, 'Calendar',
              isSelected: _currentIndex == 1),
          _navItem(Icons.family_restroom, 'Alert',
              isSelected: _currentIndex == 2),
          _navItem(Icons.notifications, 'Notifications',
              isSelected: _currentIndex == 3),
          _navItem(Icons.person, 'Profile',
              isSelected: _currentIndex == 4),
        ],
      ),
    );
  }

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

 /// Helper for nav bar icon styling
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
