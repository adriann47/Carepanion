import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'navbar_assisted.dart'; // ✅ Import your custom navbar

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                ).copyWith(bottom: 24),
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

                    const SizedBox(height: 24),

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

      /// ✅ Replaced old BottomNavigationBar with your custom widget
      bottomNavigationBar: const NavbarAssisted(currentIndex: 3),
    );
  }
}
