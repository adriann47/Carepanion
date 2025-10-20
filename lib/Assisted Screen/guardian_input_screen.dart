import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/profile_service.dart';
import 'tasks_screen.dart'; // import your tasks screen

class GuardianInputScreen extends StatefulWidget {
  const GuardianInputScreen({super.key});

  @override
  State<GuardianInputScreen> createState() => _GuardianInputScreenState();
}

class _GuardianInputScreenState extends State<GuardianInputScreen> {
  final TextEditingController _guardianController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _guardianController.dispose();
    super.dispose();
  }

  Future<void> _submitGuardian() async {
    final val = _guardianController.text.trim();
    if (val.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter guardian ID')));
      return;
    }
    // Create a guardian request (assisted_guardians row with status 'pending')
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    try {
      // First create the guardian request
      await ProfileService.requestGuardianByPublicId(
        supabase,
        guardianPublicId: val,
      );

      if (!mounted) return;
      // Show a blocking waiting dialog while we poll for guardian response
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            child: Container(
              width: 320,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'WAITING FOR GUARDIAN',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: const Color(0xFF4A4A4A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 18,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC68A),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0xFFCA5000),
                        width: 1.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          offset: const Offset(0, 4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'REQUEST SENT',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF5A2F00),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A request has been sent to your guardian. Waiting for confirmation...',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2B2B2B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFCA5000),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final status = await ProfileService.waitForGuardianResponse(
        supabase,
        timeout: const Duration(minutes: 5),
      );
      // Close waiting dialog
      if (mounted) Navigator.of(context).pop();

      if (status == 'accepted') {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Guardian accepted.')));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TasksScreen()),
        );
        return;
      } else if (status == 'rejected') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guardian rejected your request.')),
        );
        return;
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No response from guardian (timeout).')),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to request guardian: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F0), // background color
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 60),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Image.asset("assets/logo.jpg", width: 80, height: 80),
                const SizedBox(width: 15),
                // CARE-PANION text
                Transform.translate(
                  offset: const Offset(-20, 0),
                  child: Text(
                    "CARE-\nPANION",
                    textAlign: TextAlign.left,
                    style: GoogleFonts.nunito(
                      color: const Color(0xFFCA5000),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      height: 0.9,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Guardian input title
            const Text(
              "INPUT GUARDIAN",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21),
            ),
            const SizedBox(height: 5),

            // Text color matches CARE-PANION
            Text(
              "CONNECT YOUR GUARDIAN",
              style: GoogleFonts.nunito(
                color: const Color(0xFFCA5000),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 30),

            // Guardian ID TextField with white outline
            TextField(
              controller: _guardianController,
              decoration: InputDecoration(
                hintText: "ENTER GUARDIAN ID...",
                hintStyle: const TextStyle(
                  color: Color(0xFF818589), // placeholder text color
                ),
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
                  borderSide: const BorderSide(color: Colors.white, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 40), // spacing above the button
            // Submit button -> navigate to TasksScreen
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                minimumSize: const Size(200, 40),
              ),
              onPressed: _isLoading ? null : _submitGuardian,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Submit",
                      style: TextStyle(
                        color: Colors.white, // make text white
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
