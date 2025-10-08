import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'welcome_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFFCA5000)),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WelcomeScreen(),
                        ),
                      );
                    },
                  ),
                ),

                // Title
                Center(
                  child: Text(
                    "SIGN IN",
                    style: GoogleFonts.nunito(
                      color: const Color(0xFFCA5000),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Email
                Text(
                  "Email",
                  style: GoogleFonts.nunito(
                    color: const Color(0xFFCA5000),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                TextFormField(
                  controller: _emailController,
                  validator: _validateEmail,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  ),
                  style: GoogleFonts.nunito(color: const Color(0xFFCA5000)),
                ),
                const SizedBox(height: 25),

                // Password
                Text(
                  "Password",
                  style: GoogleFonts.nunito(
                    color: const Color(0xFFCA5000),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  validator: _validatePassword,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  ),
                  style: GoogleFonts.nunito(color: const Color(0xFFCA5000)),
                ),
                const SizedBox(height: 15),

                // Remember Me + Forgot Password
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Checkbox(value: false, onChanged: (_) {}),
                      Text(
                        "Remember Me",
                        style: GoogleFonts.nunito(color: const Color(0xFFCA5000)),
                      ),
                    ]),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        "Forgot password?",
                        style: GoogleFonts.nunito(color: const Color(0xFFCA5000)),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 30),

                // Log In button
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      minimumSize: const Size(200, 45),
                    ),
                    onPressed: _submitForm,
                    child: Text(
                      "Log In",
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Log In with
                Center(
                  child: Text(
                    "Log In with",
                    style: GoogleFonts.nunito(color: const Color(0xFFCA5000)),
                  ),
                ),
                const SizedBox(height: 12),

                // Google logo
                Center(
                  child: Image.asset(
                    'assets/google1.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
