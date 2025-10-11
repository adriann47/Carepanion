import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:softeng/Regular%20Screen/tasks_screen_regular.dart'; // ✅ New Regular User screen
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/profile_service.dart';
import '../Assisted Screen/guardian_input_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  _RoleSelectionScreenState createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool regularUser = false;
  bool assistedUser = false;

  // Custom Role Card
  Widget buildRoleCard({
    required String title,
    required String subtitleLine1,
    required String subtitleLine2,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    children: [
                      TextSpan(
                        text: "$subtitleLine1\n\n",
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                      TextSpan(
                        text: subtitleLine2,
                        style: const TextStyle(fontStyle: FontStyle.normal),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ✅ Custom styled checkbox
          GestureDetector(
            onTap: () => onChanged(!value),
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: value ? Colors.blueAccent : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value ? Colors.blueAccent : Colors.black45,
                  width: 1.8,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF3),

      // ✅ Content scrollable
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80), // avoids overlap
          child: Column(
            children: [
              const SizedBox(height: 30),
              Text(
                "ROLE SELECTION",
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Select the role that best fits how you’ll use Carepanion.",
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: const Color(0xB3CA5000),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),

              // Regular User / Guardian
              buildRoleCard(
                title: "REGULAR USER / GUARDIAN",
                subtitleLine1:
                    "For students, professionals, active individuals, or guardians.",
                subtitleLine2:
                    "Stay organized and productive with smart reminders for tasks, study sessions, vitamins, healthy routines, or while helping a loved one.",
                color: Colors.orange.shade300,
                value: regularUser,
                onChanged: (val) {
                  setState(() {
                    regularUser = val;
                    assistedUser = false;
                  });
                },
              ),

              // Assisted User
              buildRoleCard(
                title: "ASSISTED USER",
                subtitleLine1: "For seniors or persons with disabilities.",
                subtitleLine2:
                    "Receive simple, easy-to-follow reminders through voice or notifications which can be managed by your guardian.",
                color: Colors.pink.shade200,
                value: assistedUser,
                onChanged: (val) {
                  setState(() {
                    assistedUser = val;
                    regularUser = false;
                  });
                },
              ),
            ],
          ),
        ),
      ),

      // ✅ Button fixed at bottom
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: (regularUser || assistedUser)
              ? () async {
                  final supabase = Supabase.instance.client;
                  final role = assistedUser ? 'assisted' : 'regular';
                  // Persist role selection to profile
                  await ProfileService.ensureProfileExists(
                    supabase,
                    role: role,
                  );

                  if (assistedUser) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GuardianInputScreen(),
                      ),
                    );
                  } else if (regularUser) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TasksScreenRegular(),
                      ), // ✅ Regular User
                    );
                  }
                }
              : null,
          child: Text(
            "Continue",
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
