import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:softeng/screen/role_selection_screen.dart';
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
  // DEV-ONLY: Toggle to use a locally generated OTP instead of Supabase email OTP
  // Set to false to use Supabase's real OTP flow.
  final bool _devLocalOtp = true;
  String? _localOtp; // holds the generated 6-digit code when using local OTP

  String get _otpCode => _otpControllers.map((c) => c.text).join();
  String? get _emailOrSessionEmail {
    final w = widget.email?.trim();
    if (w != null && w.isNotEmpty) return w;
    final sessEmail = supabase.auth.currentUser?.email?.trim();
    if (sessEmail != null && sessEmail.isNotEmpty) return sessEmail;
    return null;
  }

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

  void _fillOtpControllersWith(String code) {
    setState(() {
      for (int i = 0; i < 6; i++) {
        final ch = i < code.length ? code[i] : '';
        final controller = _otpControllers[i];
        controller.value = TextEditingValue(
          text: ch,
          selection: TextSelection.collapsed(offset: ch.isEmpty ? 0 : 1),
        );
      }
    });
    // Move focus to last box to make the fill visible and ready to submit
    if (_otpFocus.isNotEmpty) {
      _otpFocus.last.requestFocus();
    }
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
    if (_devLocalOtp) {
      setState(() => _isSending = true);
      try {
        // Generate a random 6-digit code
        final now = DateTime.now().microsecondsSinceEpoch;
        final six = (now % 1000000).toString().padLeft(6, '0');
        _localOtp = six;
        _fillOtpControllersWith(six);
        if (!mounted) return;
        _startCooldown();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DEV: Your code is $six')),
        );
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
      return;
    }

    final email = _emailOrSessionEmail;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email first.')),
      );
      return;
    }
    setState(() => _isSending = true);
    try {
      await supabase.auth.signInWithOtp(
        email: email,
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
      if (_devLocalOtp) {
        final ok = _localOtp != null && code == _localOtp;
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        if (ok) {
          // In dev mode, proceed to Sign In screen after local verification
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid code.')),
          );
        }
        return;
      }

      final email = _emailOrSessionEmail;
      if (email == null || email.isEmpty) {
        throw AuthException('Email is missing');
      }
      await supabase.auth.verifyOTP(
        type: OtpType.email,
        email: email,
        token: code,
      );

      // Ensure profile exists after successful verification (session created)
      await ProfileService.ensureProfileExists(supabase, email: email);

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
              "We sent a verification code to your email.\nCheck it out and enter it below.",
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(color: primaryTextColor),
            ),
            const SizedBox(height: 100), // Space below this text
            const SizedBox(height: 30),

            const SizedBox(height: 20),

            // OTP section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'verify with 6-digit code',
                style: GoogleFonts.nunito(
                  color: primaryTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_devLocalOtp && _localOtp != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text(
                  'DEV code: $_localOtp',
                  style: GoogleFonts.nunito(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            // Intentionally hide the email from UI per request; still used internally for resend/verify
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
            Center(
              child: SizedBox(
                width: 200,
                height: 44,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
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
                      : Text(
                          'Submit',
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Resend text with "Resend" underlined
            Center(
              child: GestureDetector(
                onTap: () async {
                  if (_cooldown > 0 || _isSending) return;
                  await _sendOtp();
                },
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.nunito(color: primaryTextColor),
                    children: [
                      const TextSpan(text: "Didn't receive any code? "),
                      TextSpan(
                        text: _cooldown > 0
                            ? 'Resend in ${_cooldown}s'
                            : 'Resend',
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
            ),
          ],
        ),
      ),
    );
  }
}
