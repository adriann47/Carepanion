import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'signin_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/profile_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String? email; // email used for registration; enables resend/OTP
  const VerifyEmailScreen({super.key, this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocus = List.generate(6, (_) => FocusNode());
  bool _isSending = false;
  bool _isVerifying = false;
  final supabase = Supabase.instance.client;
  int _cooldown = 0; // seconds remaining for resend
  Timer? _cooldownTimer;

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  Future<void> _sendOtp() async {
    if (widget.email == null || widget.email!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email first.')),
      );
      return;
    }
    setState(() => _isSending = true);
    try {
      await supabase.auth.signInWithOtp(
        email: widget.email!,
        emailRedirectTo: 'https://eyalgnlsdseuvmmtgefk.supabase.co',
      );
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('OTP sent to your email.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send OTP: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpCode;
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit code.')),
      );
      return;
    }
    setState(() => _isVerifying = true);
    try {
      await supabase.auth.verifyOTP(
        type: OtpType.email,
        email: widget.email!,
        token: code,
      );

      // Ensure profile exists after successful verification (session created)
      await ProfileService.ensureProfileExists(supabase, email: widget.email);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('OTP verification failed: $e')));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryTextColor = Color(0xFFCA5000); // All text except button

    // No code inputs needed; verification occurs via email link

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F0),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 80),

            // Verify your Email Address (bold, multi-line)
            Text(
              "Verify your Email",
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
              "We sent a verification link to your email.\nOpen the link to confirm, then return here and sign in.",
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(color: primaryTextColor),
            ),
            const SizedBox(height: 100), // Space below this text
            const SizedBox(height: 30),

            if (widget.email != null)
              Text(
                widget.email!,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  color: primaryTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),

            const SizedBox(height: 20),

            if (widget.email != null)
              OutlinedButton(
                onPressed: () async {
                  try {
                    await Supabase.instance.client.auth.resend(
                      type: OtpType.signup,
                      email: widget.email!,
                      emailRedirectTo:
                          'https://eyalgnlsdseuvmmtgefk.supabase.co',
                    );
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Verification email resent.'),
                      ),
                    );
                  } catch (e) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to resend: $e')),
                    );
                  }
                },
                child: Text(
                  'Resend verification email',
                  style: GoogleFonts.nunito(color: primaryTextColor),
                ),
              ),

            const SizedBox(height: 20),

            // OTP section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Or verify with 6-digit code',
                style: GoogleFonts.nunito(
                  color: primaryTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 45,
                  child: TextField(
                    controller: _otpControllers[index],
                    focusNode: _otpFocus[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(1),
                    ],
                    onChanged: (v) {
                      if (v.isNotEmpty && index < 5) {
                        _otpFocus[index + 1].requestFocus();
                      }
                      if (v.isEmpty && index > 0) {
                        _otpFocus[index - 1].requestFocus();
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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: (_isSending || _cooldown > 0) ? null : _sendOtp,
                  child: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _cooldown > 0
                              ? 'Resend in ${_cooldown}s'
                              : 'Send OTP',
                        ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    minimumSize: const Size(120, 40),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Verify OTP'),
                ),
              ],
            ),

            // Submit button (navigate to RoleSelectionScreen)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                minimumSize: const Size(200, 40),
              ),
              onPressed: () {
                // After verifying via email link, user should sign in to create a session
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SignInScreen()),
                );
              },
              child: Text(
                "I verified — Sign In",
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
                  style: GoogleFonts.nunito(color: primaryTextColor),
                  children: [
                    const TextSpan(text: "Didn't receive the email? "),
                    TextSpan(
                      text: "Resend from Sign In",
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
