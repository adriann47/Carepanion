import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'registration_email_screen.dart';
import 'verify_email_screen.dart'; // Import your verify email screen
import 'welcome_screen.dart'; // Import your welcome screen

class RegistrationPhoneScreen extends StatefulWidget {
  const RegistrationPhoneScreen({super.key});

  @override
  State<RegistrationPhoneScreen> createState() => _RegistrationPhoneScreenState();
}

class _RegistrationPhoneScreenState extends State<RegistrationPhoneScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String? _errorMessage;

  void _validatePhoneAndProceed(BuildContext context) {
    String phone = _phoneController.text.trim();

    // Check if input is numeric and 11 digits
    if (phone.isEmpty) {
      setState(() => _errorMessage = "Phone number is required");
    } else if (!RegExp(r'^[0-9]{11}$').hasMatch(phone)) {
      setState(() => _errorMessage = "Phone number must be exactly 11 digits");
    } else {
      setState(() => _errorMessage = null);

      // ✅ If valid, navigate to VerifyEmailScreen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const VerifyEmailScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryTextColor = Color(0xFFDA6319);

    return Scaffold(
      backgroundColor: const Color(0xFFFEF9F3),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Back button
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFFDA6319)),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WelcomeScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Registration title
              Center(
                child: Text(
                  "REGISTRATION",
                  style: GoogleFonts.nunito(
                    color: primaryTextColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Email / Phone Number tabs
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const RegistrationEmailScreen()),
                      );
                    },
                    child: Transform.translate(
                      offset: const Offset(-20, 0),
                      child: Container(
                        width: 160,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            "Email",
                            style: GoogleFonts.nunito(
                              color: primaryTextColor,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              decorationColor: primaryTextColor,
                              decorationThickness: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 30),
                  Container(
                    width: 160,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC6D0D8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        "Phone Number",
                        style: GoogleFonts.nunito(
                          color: primaryTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Phone Number Field
              Text(
                "Phone Number",
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  counterText: "", // hides counter
                  errorText: _errorMessage, // shows error message
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Other Fields (First Name, Last Name, Password)
              Text(
                "First Name",
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                "Last Name",
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                "Password",
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 30),

              // Create Account Button
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    minimumSize: const Size(220, 50),
                  ),
                  onPressed: () => _validatePhoneAndProceed(context),
                  child: Text(
                    "Create Account",
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              Center(
                child: Text(
                  "Do you have an account already? Sign In",
                  style: GoogleFonts.nunito(
                    color: primaryTextColor,
                    decoration: TextDecoration.underline,
                    decorationColor: primaryTextColor,
                    decorationThickness: 2,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Center(
                child: Text(
                  "Sign in with",
                  style: GoogleFonts.nunito(color: primaryTextColor),
                ),
              ),
              const SizedBox(height: 10),

              Center(
                child: Image.asset(
                  'assets/google1.png',
                  width: 40,
                  height: 40,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
