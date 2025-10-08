import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'registration_phone_screen.dart';
import 'verify_email_screen.dart';
import 'welcome_screen.dart';

class RegistrationEmailScreen extends StatefulWidget {
  const RegistrationEmailScreen({super.key});

  @override
  State<RegistrationEmailScreen> createState() =>
      _RegistrationEmailScreenState();
}

class _RegistrationEmailScreenState extends State<RegistrationEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  // Email validator
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Email is required";
    if (!value.endsWith("@gmail.com")) {
      return "Email must be a @gmail.com address";
    }
    return null;
  }

  // Password validator
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Password is required";
    if (value.length < 6) return "Must be at least 6 characters";
    if (!RegExp(r'[A-Z]').hasMatch(value)) return "Must contain 1 uppercase letter";
    if (!RegExp(r'[0-9]').hasMatch(value)) return "Must contain 1 number";
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return "Must contain 1 special character";
    }
    return null;
  }

  // Confirm password validator
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return "Please confirm your password";
    if (value != _passwordController.text) return "Passwords do not match";
    return null;
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const VerifyEmailScreen(),
        ),
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
          child: Form(
            key: _formKey,
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

                // Email / Phone Number toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset: const Offset(-20, 0),
                      child: Container(
                        width: 160,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC6D0D8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            "Email",
                            style: GoogleFonts.nunito(
                              color: primaryTextColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 30),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const RegistrationPhoneScreen(),
                          ),
                        );
                      },
                      child: Text(
                        "Phone Number",
                        style: GoogleFonts.nunito(
                          color: primaryTextColor,
                          decoration: TextDecoration.underline,
                          decorationColor: primaryTextColor,
                          decorationThickness: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Email
                Text(
                  "Email",
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  validator: _validateEmail,
                  decoration: _inputDecoration(),
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
                TextFormField(
                  controller: _firstNameController,
                  decoration: _inputDecoration(),
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
                TextFormField(
                  controller: _lastNameController,
                  decoration: _inputDecoration(),
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
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  validator: _validatePassword,
                  decoration: _inputDecoration(),
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
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  validator: _validateConfirmPassword,
                  decoration: _inputDecoration(),
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
                    onPressed: _submitForm,
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
                const SizedBox(height: 20),

                // Already have account?
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

                // Sign in with
                Center(
                  child: Text(
                    "Sign in with",
                    style: GoogleFonts.nunito(
                      color: primaryTextColor,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Google logo
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
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white),
      ),
    );
  }
}
