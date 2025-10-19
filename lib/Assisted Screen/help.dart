import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'navbar_assisted.dart'; // ✅ Import your custom navbar

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
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
                /// Question
                Text(
                  question,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 18),

                /// Answers in bullet points
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

                /// OK Button
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
            /// --- TOP PINK HEADER ---
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

            /// --- FAQ TITLE ---
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

            /// --- FAQ LIST ---
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

      /// ✅ Replaced old BottomNavigationBar with your custom widget
      bottomNavigationBar: const NavbarAssisted(currentIndex: 3),
    );
  }
}

/// --- FAQ QUESTION WIDGET ---
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
