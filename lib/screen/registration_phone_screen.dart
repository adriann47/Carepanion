import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'registration_email_screen.dart';
import 'verify_email_screen.dart'; // Import your verify email screen
import 'welcome_screen.dart'; // Import your welcome screen
import 'signin_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/profile_service.dart';

class RegistrationPhoneScreen extends StatefulWidget {
  const RegistrationPhoneScreen({super.key});

  @override
  State<RegistrationPhoneScreen> createState() =>
      _RegistrationPhoneScreenState();
}

class _RegistrationPhoneScreenState extends State<RegistrationPhoneScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  final supabase = Supabase.instance.client;

  String? _toE164(String raw) {
    // If already in E.164, pass through
    if (raw.startsWith('+') && raw.length > 8) return raw;
    // Strip non-digits
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length == 11 && d.startsWith('0')) {
      // Assume PH local 11-digit number starting with 0 -> +63
      return '+63${d.substring(1)}';
    }
    // Fallback: return null to indicate invalid format
    return null;
  }

  void _validatePhoneAndProceed(BuildContext context) {
    String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = "Phone number is required");
      return;
    }

    final e164 = _toE164(phone);
    if (e164 == null) {
      setState(() => _errorMessage = "Enter a valid PH number (e.g., 09XXXXXXXXX)");
      return;
    }

    setState(() => _errorMessage = null);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VerifyEmailScreen(phone: e164)),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'https://eyalgnlsdseuvmmtgefk.supabase.co/auth/v1/callback',
      );

      // Wait briefly for redirect/login to complete
      await Future.delayed(const Duration(seconds: 3));

      final user = supabase.auth.currentUser;
      if (user != null) {
        await ProfileService.ensureProfileExists(supabase, email: user.email);
        if (!mounted) return;
        // Navigate to welcome (or adjust to your desired post-OAuth screen)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google sign-in failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                          builder: (context) => const RegistrationEmailScreen(),
                        ),
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
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), // ✅ radius 10
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // First Name
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
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Last Name
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
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Password
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
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Confirm Password
              Text(
                "Confirm Password",
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
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Create Account Button
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
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

              // Already have an account?
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignInScreen(),
                      ),
                    );
                  },
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.nunito(
                        color: primaryTextColor,
                        fontSize: 16,
                      ),
                      children: [
                        const TextSpan(
                          text: "Do you have an account already? ",
                        ),
                        TextSpan(
                          text: "Sign in",
                          style: GoogleFonts.nunito(
                            color: primaryTextColor,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: primaryTextColor,
                            decorationThickness: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              // Google sign-in button
              Center(
                child: InkWell(
                  onTap: _isLoading ? null : _signInWithGoogle,
                  child: Opacity(
                    opacity: _isLoading ? 0.5 : 1.0,
                    child: Image.asset(
                      'assets/google1.png',
                      width: 40,
                      height: 40,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
