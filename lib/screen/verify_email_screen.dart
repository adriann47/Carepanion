import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'role_selection_screen.dart'; // Import your RoleSelectionScreen

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryTextColor = Color(0xFFCA5000); // All text except button

    // Controllers and focus nodes for 6-digit fields
    final List<TextEditingController> controllers =
        List.generate(6, (index) => TextEditingController());
    final List<FocusNode> focusNodes = List.generate(6, (index) => FocusNode());

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F0),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 80),

            // Verify your Email Address (bold, multi-line)
            Text(
              "Verify your\nEmail Address",
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                color: primaryTextColor,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Verify message
            Text(
              "Verify your email address to proceed.",
              style: GoogleFonts.nunito(
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 100), // Space below this text

            // 6-digit instruction (keep as-is)
            Text(
              "Enter the 6 digits code sent to your\n            email address below.",
              textAlign: TextAlign.justify,
              style: GoogleFonts.nunito(
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 35),

            // "Enter code" label above the first field
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Enter code",
                style: GoogleFonts.nunito(
                  color: primaryTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 6-digit code input fields (1 digit only, auto-focus)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 50, // Wider to display number properly
                  child: TextField(
                    controller: controllers[index],
                    focusNode: focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(1),
                    ],
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 5) {
                        FocusScope.of(context).requestFocus(focusNodes[index + 1]);
                      }
                      if (value.isEmpty && index > 0) {
                        FocusScope.of(context).requestFocus(focusNodes[index - 1]);
                      }
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 30),

            // Submit button (navigate to RoleSelectionScreen)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                minimumSize: const Size(200, 40),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RoleSelectionScreen(),
                  ),
                );
              },
              child: Text(
                "Submit",
                style: GoogleFonts.nunito(
                  color: Colors.white, // White text
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Resend text with "Resend" underlined
            Center(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.nunito(
                    color: primaryTextColor,
                  ),
                  children: [
                    const TextSpan(text: "Didn't receive any code? "),
                    TextSpan(
                      text: "Resend",
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFFCA5000),
                        decorationThickness: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
