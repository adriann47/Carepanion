import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  bool _rememberMe = false;
  bool _isLoading = false;

  final supabase = Supabase.instance.client;

  // Email validator - less restrictive
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Email is required";
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value))
      return "Please enter a valid email address";
    return null;
  }

  // Password validator
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Password is required";
    if (value.length < 6) return "Must be at least 6 characters";
    if (!RegExp(r'[A-Z]').hasMatch(value))
      return "Must contain 1 uppercase letter";
    if (!RegExp(r'[0-9]').hasMatch(value)) return "Must contain 1 number";
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value))
      return "Must contain 1 special character";
    return null;
  }

  /// ✅ Email + Password Sign In
  Future<void> _signInWithEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final response = await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (response.user != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          );
        }
      } on AuthException catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An unexpected error occurred")),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  /// ✅ Google Sign In - Simple Supabase OAuth
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'https://eyalgnlsdseuvmmtgefk.supabase.co/auth/v1/callback',
      );
    } on AuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Google sign-in failed: $e")));
    } finally {
      setState(() => _isLoading = false);
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
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFFCA5000),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const WelcomeScreen(),
                              ),
                            );
                          },
                  ),
                ),
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

                // Email field
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
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                  ),
                  style: GoogleFonts.nunito(color: const Color(0xFFCA5000)),
                ),
                const SizedBox(height: 25),

                // Password field
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
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                  ),
                  style: GoogleFonts.nunito(color: const Color(0xFFCA5000)),
                ),
                const SizedBox(height: 15),

                // Remember Me + Forgot Password
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  setState(() => _rememberMe = value ?? false);
                                },
                        ),
                        Text(
                          "Remember Me",
                          style: GoogleFonts.nunito(
                            color: const Color(0xFFCA5000),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : () {},
                      child: Text(
                        "Forgot password?",
                        style: GoogleFonts.nunito(
                          color: const Color(0xFFCA5000),
                        ),
                      ),
                    ),
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
                    onPressed: _isLoading ? null : _signInWithEmail,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
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

                Center(
                  child: Text(
                    "Log In with",
                    style: GoogleFonts.nunito(color: const Color(0xFFCA5000)),
                  ),
                ),
                const SizedBox(height: 12),

                // Google logo as button
                Center(
                  child: InkWell(
                    onTap: _isLoading ? null : _signInWithGoogle,
                    child: Opacity(
                      opacity: _isLoading ? 0.5 : 1.0,
                      child: Image.asset(
                        'assets/google1.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
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
