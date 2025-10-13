import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:softeng/screen/role_selection_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/profile_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String? email; // email used for registration; enables resend/OTP
  final String? phone; // phone in E.164 format (+63...), enables SMS OTP
  final String? fullName; // optional, used to prefill profile after OTP
  const VerifyEmailScreen({super.key, this.email, this.phone, this.fullName});

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
  final bool _devLocalOtp = false; // Step A: use real email OTP
  String? _localOtp; // holds the generated 6-digit code when using local OTP
  bool _autoSent = false; // ensure we only auto-send once
  // If SMS is requested but the provider is disabled, allow opting-in to email fallback.
  bool _forceEmailFallback = false;

  String get _otpCode => _otpControllers.map((c) => c.text).join();
  String? get _emailOrSessionEmail {
    final w = widget.email?.trim();
    if (w != null && w.isNotEmpty) return w;
    final sessEmail = supabase.auth.currentUser?.email?.trim();
    if (sessEmail != null && sessEmail.isNotEmpty) return sessEmail;
    return null;
  }

  String? get _phoneFromWidget => widget.phone?.trim();
  bool get _useSms =>
      !_forceEmailFallback &&
      (_phoneFromWidget != null && _phoneFromWidget!.isNotEmpty);

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

  @override
  void initState() {
    super.initState();
    // Auto-send OTP on first build when email is available and we're using real email OTP
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_devLocalOtp &&
          !_autoSent &&
          (_emailOrSessionEmail != null || _useSms)) {
        _autoSent = true;
        await _sendOtp();
      }
    });
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('DEV: Your code is $six')));
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
      return;
    }

    // Real OTP via Supabase: branch by method (SMS vs Email)
    setState(() => _isSending = true);
    try {
      if (_useSms) {
        final phone = _phoneFromWidget;
        if (phone == null || phone.isEmpty) {
          throw AuthException('Phone number is missing');
        }
        await supabase.auth.signInWithOtp(phone: phone);
      } else {
        final email = _emailOrSessionEmail;
        if (email == null || email.isEmpty) {
          throw AuthException('Email is missing');
        }
        // IMPORTANT: For signup confirmation, resend a SIGNUP OTP (not a login OTP)
        await supabase.auth.resend(
          type: OtpType.signup,
          email: email,
        );
      }
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _useSms ? 'OTP sent via SMS.' : 'OTP sent to your email.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      // If SMS provider isn't configured in Supabase, offer an email fallback (when available)
      if (_useSms && msg.toLowerCase().contains('phone_provider_disabled')) {
        await _handleSmsProviderDisabled();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send OTP: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleSmsProviderDisabled() async {
    final email = _emailOrSessionEmail;
    final canFallback = email != null && email.isNotEmpty;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('SMS not available'),
        content: const Text(
          'Your Supabase project has Phone/SMS auth disabled or not configured. Enable a provider (Twilio/MessageBird) in Supabase → Authentication → Providers → Phone to send SMS codes.\n\nIf you prefer, you can use an email code instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('close'),
            child: const Text('Close'),
          ),
          if (canFallback)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('email'),
              child: const Text('Use Email Instead'),
            ),
        ],
      ),
    );

    if (!mounted) return;
    if (result == 'email' && canFallback) {
      setState(() {
        _forceEmailFallback = true; // Switch UI/logic to email mode
      });
      // Trigger an email OTP send immediately
      await _sendOtp();
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid code.')));
        }
        return;
      }
      if (_useSms) {
        final phone = _phoneFromWidget;
        if (phone == null || phone.isEmpty) {
          throw AuthException('Phone number is missing');
        }
        await supabase.auth.verifyOTP(
          type: OtpType.sms,
          phone: phone,
          token: code,
        );
      } else {
        final email = _emailOrSessionEmail;
        if (email == null || email.isEmpty) {
          throw AuthException('Email is missing');
        }
        // IMPORTANT: Use SIGNUP type so Supabase marks email_confirmed_at
        await supabase.auth.verifyOTP(
          type: OtpType.signup,
          email: email,
          token: code,
        );
      }

      // Ensure profile exists after successful verification (session created)
      await ProfileService.ensureProfileExists(
        supabase,
        email: _useSms ? null : _emailOrSessionEmail,
        fullName: widget.fullName,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
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
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F0),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 80),

            // Verify your Email Address (bold, multi-line)
            Text(
              _useSms ? "Verify your Phone Number" : "Verify your Email",
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
              _useSms
                  ? "We sent a 6-digit code to your phone via SMS.\nEnter the code below to continue."
                  : "We sent a verification link and a 6-digit code to your email.\nEnter the code below to continue.",
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
                'Or verify with 6-digit code',
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
