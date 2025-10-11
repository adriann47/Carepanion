import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'welcome_screen.dart';
import '../data/profile_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
  StreamSubscription<AuthState>? _authSub;
  bool _googleOAuthPending = false;

  // Email validator - less restrictive
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Email is required";
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return "Please enter a valid email address";
    }
    return null;
  }

  // Password validator
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Password is required";
    if (value.length < 6) return "Must be at least 6 characters";
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return "Must contain 1 uppercase letter";
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) return "Must contain 1 number";
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return "Must contain 1 special character";
    }
    return null;
  }

  /// ✅ Ensure profile exists for authenticated user
  Future<void> _ensureProfileExists() async {
    final user = supabase.auth.currentUser;
    String? fullName;
    final dynamic rawMeta = user?.userMetadata;
    final Map<String, dynamic>? meta = rawMeta is Map<String, dynamic>
        ? rawMeta
        : null;
    if (meta != null) {
      final String? given = (meta['first_name'] ?? meta['given_name'])
          ?.toString();
      final String? family = (meta['last_name'] ?? meta['family_name'])
          ?.toString();
      final String? composite = (meta['full_name'] ?? meta['name'])?.toString();

      final parts = <String>[
        if (given != null && given.isNotEmpty) given,
        if (family != null && family.isNotEmpty) family,
      ];

      fullName = parts.isNotEmpty ? parts.join(' ') : composite;
    }

    await ProfileService.ensureProfileExists(
      supabase,
      email: user?.email,
      fullName: fullName,
    );
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

        if (!mounted) return;

        if (response.user != null) {
          // Ensure profile exists in database
          await _ensureProfileExists();

          if (!mounted) return;
          // Navigate to welcome screen
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
        ).showSnackBar(SnackBar(content: Text("Sign-in failed: $e")));
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  /// ✅ Google Sign In
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      _googleOAuthPending = true;
      // Web: redirect back to current origin; Mobile: use deep link scheme
      final redirect = kIsWeb ? Uri.base.origin : 'io.supabase.flutter://callback';
      // Force external system browser for the auth flow to avoid embedded webviews
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirect,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      // Navigation will be handled by onAuthStateChange listener in initState.
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Google sign-in failed: $e")));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Listen for auth state changes to complete OAuth flows reliably
    _authSub = supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        // Ensure profile exists, then navigate
        await _ensureProfileExists();
        if (!mounted) return;
        final user = supabase.auth.currentUser;
        if (_googleOAuthPending) {
          _googleOAuthPending = false;
          Navigator.pushReplacementNamed(context, '/google_registration');
          return;
        }
        final Map<String, dynamic>? meta = user?.appMetadata;
        final provider = (meta != null ? meta['provider'] : '')?.toString();
        if (provider == 'google') {
          // After Google OAuth, go to GoogleRegistration screen
          Navigator.pushReplacementNamed(context, '/google_registration');
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
