import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'registration_phone_screen.dart';
import 'verify_email_screen.dart';
import 'welcome_screen.dart';
import '../data/profile_service.dart';
import 'signin_screen.dart';

class RegistrationEmailScreen extends StatefulWidget {
  const RegistrationEmailScreen({super.key});

  @override
  State<RegistrationEmailScreen> createState() =>
      _RegistrationEmailScreenState();
}

class _PasswordChecklist extends StatelessWidget {
  final bool lenOk;
  final bool upperOk;
  final bool digitOk;
  final bool specialOk;

  const _PasswordChecklist({
    required this.lenOk,
    required this.upperOk,
    required this.digitOk,
    required this.specialOk,
  });

  Widget _row(String text, bool ok) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: ok ? Colors.green : Colors.redAccent,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: const Color(0xFFDA6319),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('At least 6 characters', lenOk),
        const SizedBox(height: 4),
        _row('Contains 1 uppercase letter', upperOk),
        const SizedBox(height: 4),
        _row('Contains 1 digit', digitOk),
        const SizedBox(height: 4),
        _row('Contains 1 special character', specialOk),
      ],
    );
  }
}

class _RuleIndicatorRow extends StatelessWidget {
  final bool ok;
  final String text;

  const _RuleIndicatorRow({required this.ok, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: ok ? Colors.green : Colors.redAccent,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: const Color(0xFFDA6319),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RegistrationEmailScreenState extends State<RegistrationEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  bool _isLoading = false; // Add loading state
  final supabase = Supabase.instance.client;

  // Live password rule indicators
  bool _ruleLen = false;
  bool _ruleUpper = false;
  bool _ruleDigit = false;
  bool _ruleSpecial = false;

  // Password visibility toggles
  bool _passwordObscured = true;
  bool _confirmPasswordObscured = true;

  // Email validity indicator
  bool _emailValid = false;

  void _updateEmailValidity(String value) {
    final v = value.trim().toLowerCase();
    // Simple rule: must be a @gmail.com address with something before @
    final atIndex = v.indexOf('@');
    final hasLocal = atIndex > 0; // at least 1 char before '@'
    setState(() {
      _emailValid = v.endsWith('@gmail.com') && hasLocal;
    });
  }

  void _updatePasswordRules(String value) {
    setState(() {
      _ruleLen = value.length >= 6;
      _ruleUpper = RegExp(r'[A-Z]').hasMatch(value);
      _ruleDigit = RegExp(r'[0-9]').hasMatch(value);
      _ruleSpecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value);
    });
  }

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
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return "Must contain 1 uppercase letter";
    }
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

  /// ✅ Email + Password Registration
  Future<void> _registerWithEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // 1. Create auth user
        final authResponse = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {
            'first_name': _firstNameController.text.trim(),
            'last_name': _lastNameController.text.trim(),
          },
          emailRedirectTo: 'https://eyalgnlsdseuvmmtgefk.supabase.co',
        );

        if (authResponse.user != null) {
          // 2. Only upsert profile if there's an active session (email confirmation might be required)
          final hasSession =
              supabase.auth.currentSession != null ||
              authResponse.session != null;
          if (hasSession) {
            await ProfileService.upsertProfile(
              supabase,
              id: authResponse.user!.id,
              email: _emailController.text.trim(),
              fullName:
                  '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
            );
          }

          // 3. Navigate to verify email screen
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  VerifyEmailScreen(email: _emailController.text.trim()),
            ),
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
        ).showSnackBar(SnackBar(content: Text("Registration failed: $e")));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  /// ✅ Google Sign In
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'https://eyalgnlsdseuvmmtgefk.supabase.co/auth/v1/callback',
      );

      // After successful Google OAuth, ensure profile exists (in case no DB trigger)
      await Future.delayed(const Duration(seconds: 3));
      final user = supabase.auth.currentUser;
      if (user != null) {
        await ProfileService.ensureProfileExists(supabase, email: user.email);
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
      ).showSnackBar(SnackBar(content: Text("Google sign-in failed: $e")));
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Back button
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFFDA6319)),
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
                      onTap: _isLoading
                          ? null
                          : () {
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
                          fontWeight: FontWeight.bold,
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
                  enabled: !_isLoading,
                  onChanged: _updateEmailValidity,
                  decoration: _inputDecoration(),
                ),
                const SizedBox(height: 8),
                _RuleIndicatorRow(
                  ok: _emailValid,
                  text: 'Valid @gmail.com email',
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
                  enabled: !_isLoading,
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
                  enabled: !_isLoading,
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
                  obscureText: _passwordObscured,
                  validator: _validatePassword,
                  enabled: !_isLoading,
                  onChanged: _updatePasswordRules,
                  decoration: _inputDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordObscured
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: const Color(0xFFDA6319),
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordObscured = !_passwordObscured;
                        });
                      },
                      tooltip: _passwordObscured
                          ? 'Show password'
                          : 'Hide password',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _PasswordChecklist(
                  lenOk: _ruleLen,
                  upperOk: _ruleUpper,
                  digitOk: _ruleDigit,
                  specialOk: _ruleSpecial,
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
                  obscureText: _confirmPasswordObscured,
                  validator: _validateConfirmPassword,
                  enabled: !_isLoading,
                  decoration: _inputDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _confirmPasswordObscured
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: const Color(0xFFDA6319),
                      ),
                      onPressed: () {
                        setState(() {
                          _confirmPasswordObscured = !_confirmPasswordObscured;
                        });
                      },
                      tooltip: _confirmPasswordObscured
                          ? 'Show password'
                          : 'Hide password',
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
                    onPressed: _isLoading ? null : _registerWithEmail,
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

                // Already have an account?
                Center(
                  child: GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () {
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

                // Sign up with Google
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
      ),
    );
  }

  InputDecoration _inputDecoration({Widget? suffixIcon}) {
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
      suffixIcon: suffixIcon,
    );
  }
}
