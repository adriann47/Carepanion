import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:softeng/Regular Screen/notification_screen.dart';
import 'account_regular.dart';
import 'notification_regular.dart';
import 'tasks_screen_regular.dart';
import 'calendar_screen_regular.dart';
import 'profile_screen_regular.dart';
import 'companion_list.dart';
import '/screen/welcome_screen.dart'; 

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _currentIndex = 4;
  int _selectedStars = 0;

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
        MaterialPageRoute(builder: (context) => CompanionListScreen()),
      );
    } else if (index == 3) {
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

  /// --- REPORT BUG DIALOG ---
  void _showReportBugDialog(BuildContext context) {
    final TextEditingController _controller = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _buildCustomDialog(
          title: "REPORT A BUG",
          textController: _controller,
          hint: "ENTER CONCERN..",
          onSubmit: () {
            print("Bug reported: ${_controller.text}");
            Navigator.pop(context);
          },
        );
      },
    );
  }

  /// --- FEEDBACK DIALOG ---
  void _showFeedbackDialog(BuildContext context) {
    final TextEditingController _controller = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _buildCustomDialog(
              title: "FEEDBACK",
              textController: _controller,
              hint: "ENTER FEEDBACK...",
              extraWidget: _buildStars(setDialogState),
              onSubmit: () {
                print("Feedback: ${_controller.text}, Stars: $_selectedStars");
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCustomDialog({
    required String title,
    required TextEditingController textController,
    required String hint,
    Widget? extraWidget,
    required VoidCallback onSubmit,
  }) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 16),
            if (extraWidget != null) extraWidget,
            if (extraWidget != null) const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 3,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(fontWeight: FontWeight.bold),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFEE7897), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFEE7897),
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEE7897),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                  onPressed: onSubmit,
                  child: Text(
                    "Submit",
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStars(StateSetter setDialogState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedStars = index + 1;
              });
              setDialogState(() {});
            },
            child: Icon(
              index < _selectedStars ? Icons.star : Icons.star_border,
              color: index < _selectedStars ? Colors.amber : Colors.grey,
              size: 32,
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF5F0),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: h * 0.20,
            decoration: const BoxDecoration(
              color: Color(0xFFF7A9AC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.05, vertical: h * 0.02),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfileScreen()),
                      );
                    },
                    icon: Icon(Icons.arrow_back,
                        size: w * 0.07, color: const Color(0xFF3D3D3D)),
                  ),
                  SizedBox(height: h * 0.01),
                  Text("SETTINGS",
                      style: GoogleFonts.nunito(
                        fontSize: w * 0.08,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF3D3D3D),
                        letterSpacing: 1.0,
                      )),
                ],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.06, vertical: h * 0.025),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("GENERAL",
                        style: GoogleFonts.nunito(
                          fontSize: w * 0.035,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4A4A4A),
                          letterSpacing: 0.8,
                        )),
                    SizedBox(height: h * 0.015),
                    InkWell(
                      onTap: () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (context) => const AccountPage()));
                      },
                      child: _buildSettingRow(Icons.person, "ACCOUNT", w, h),
                    ),
                    _divider(w),
                    InkWell(
                      onTap: () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (context) => NotificationPage()));
                      },
                      child: _buildSettingRow(Icons.notifications, "NOTIFICATIONS", w, h),
                    ),
                    _divider(w),
                    // ✅ LOGOUT functionality added
                    InkWell(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WelcomeScreen(),
                          ),
                        );
                      },
                      child: _buildSettingRow(Icons.logout, "LOGOUT", w, h),
                    ),
                    SizedBox(height: h * 0.03),

                    Text("FEEDBACK",
                        style: GoogleFonts.nunito(
                          fontSize: w * 0.035,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4A4A4A),
                          letterSpacing: 0.8,
                        )),
                    SizedBox(height: h * 0.015),
                    InkWell(
                      onTap: () => _showReportBugDialog(context),
                      child: _buildSettingRow(Icons.bug_report, "REPORT BUG", w, h),
                    ),
                    _divider(w),
                    InkWell(
                      onTap: () => _showFeedbackDialog(context),
                      child: _buildSettingRow(Icons.chat, "SEND FEEDBACK", w, h),
                    ),
                    SizedBox(height: h * 0.05),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // ✅ 5-BUTTON NAVBAR
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
          _navItem(Icons.calendar_today, 'Calendar', isSelected: _currentIndex == 1),
          _navItem(Icons.family_restroom, 'Alert', isSelected: _currentIndex == 2),
          _navItem(Icons.notifications, 'Notifications', isSelected: _currentIndex == 3),
          _navItem(Icons.person, 'Profile', isSelected: _currentIndex == 4),
        ],
      ),
    );
  }

  Widget _buildSettingRow(IconData icon, String text, double w, double h) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: h * 0.015),
      child: Row(
        children: [
          Container(
            width: w * 0.1,
            height: w * 0.1,
            decoration: const BoxDecoration(
              color: Color(0xFFE9ECEF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: w * 0.05, color: const Color(0xFF3D3D3D)),
          ),
          SizedBox(width: w * 0.04),
          Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: w * 0.04,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF514E4C),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(double w) {
    return Padding(
      padding: EdgeInsets.only(left: w * 0.14),
      child: const Divider(
        thickness: 1.0,
        height: 1,
        color: Color(0xFFE8E2DF),
      ),
    );
  }

  static BottomNavigationBarItem _navItem(IconData icon, String label,
      {bool isSelected = false}) {
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
          child: Icon(icon,
              size: 28, color: isSelected ? Colors.pink : Colors.black87),
        ),
      ),
    );
  }
}
