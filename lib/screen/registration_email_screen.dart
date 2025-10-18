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

  bool _isLoading = false;
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

  // duplicate-email UI state
  bool _emailAlreadyUsed = false;
  String? _emailStatusMessage;

  Future<bool> _showEmailInUseDialog() async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Email already in use',
          style: GoogleFonts.nunito(
            color: const Color(0xFFDA6319),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'This email address is already in use.',
          style: GoogleFonts.nunito(
            color: const Color(0xFF6B4B3A),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.nunito(
                color: const Color(0xFFDA6319),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'OK',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _showSimpleAlert(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: Text(message, style: GoogleFonts.nunito()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

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

  Future<void> _registerWithEmail() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final fullName =
        (_firstNameController.text.trim() +
                ' ' +
                _lastNameController.text.trim())
            .trim();

    try {
      // ✅ Send the name into Auth metadata so the DB trigger can copy it to public.profile
      final res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName}, // <-- important
      );

      if (res.user != null) {
        // If we already have a session, also upsert into profile directly (belt & suspenders).
        final hasSession =
            supabase.auth.currentSession != null || res.session != null;
        if (hasSession) {
          await ProfileService.upsertProfile(
            supabase,
            id: res.user!.id,
            email: email,
            fullName: fullName.isEmpty ? null : fullName,
          );
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyEmailScreen(
              email: email,
              fullName: fullName.isEmpty ? null : fullName,
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registration failed.')));
    } on AuthException catch (e) {
      if (!mounted) return;
      // If this is a duplicate email case, update the indicator and optionally show dialog
      final message = e.message.toLowerCase();
      if (message.contains('already') && message.contains('use')) {
        setState(() {
          _emailAlreadyUsed = true;
          _emailStatusMessage = 'Email already in use';
        });
        await _showEmailInUseDialog();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (msg.contains('row-level security') || msg.contains('42501')) {
        // Ignore RLS error from profile trigger, proceed with registration
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyEmailScreen(
              email: email,
              fullName: fullName.isEmpty ? null : fullName,
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updatePasswordRules(String value) {
    setState(() {
      _ruleLen = value.length >= 6;
      _ruleUpper = RegExp(r'[A-Z]').hasMatch(value);
      _ruleDigit = RegExp(r'[0-9]').hasMatch(value);
      _ruleSpecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value);
    });
  }

  void _updateEmailValidity(String value) {
    final v = value.trim();
    final ok = v.contains('@') && v.contains('.');
    setState(() {
      _emailValid = ok;
      if (ok) {
        _emailAlreadyUsed = false;
        _emailStatusMessage = null;
      }
    });
  }

  String? _validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Email is required';
    if (!v.contains('@') || !v.contains('.')) return 'Invalid email format';
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.length < 6) return 'At least 6 characters';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Must contain 1 uppercase letter';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Must contain 1 digit';
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(v)) {
      return 'Must contain 1 special character';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
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

                // Dynamic indicator (turns red if duplicate)
                _RuleIndicatorRow(
                  ok: !_emailAlreadyUsed && _emailValid,
                  text: _emailAlreadyUsed
                      ? (_emailStatusMessage ?? 'Email already in use')
                      : _emailValid
                      ? 'Valid @gmail.com email'
                      : 'Invalid email format',
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

                // Sign up with Google (optional UI hook)
                // You can add a button here that calls _signInWithGoogle()
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
