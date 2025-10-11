import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'navbar_assisted.dart'; // ✅ Import your shared navbar file

class LegalDataPage extends StatefulWidget {
  const LegalDataPage({super.key});

  @override
  State<LegalDataPage> createState() => _LegalDataPageState();
}

class _LegalDataPageState extends State<LegalDataPage> {
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
                    // Logo image
                    Image.asset(
                      "assets/nameLogo.jpg",
                      width: 200,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 30),

                    // Description
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

      /// --- CUSTOM NAV BAR ---
      bottomNavigationBar: const NavbarAssisted(currentIndex: 3), // ✅ Use shared widget
    );
  }
}
