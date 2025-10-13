import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF9F3),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset("assets/logo.jpg", width: 120, height: 120),
                      const SizedBox(width: 20),
                      Transform.translate(
                        offset: const Offset(-40, 0),
                        child: Text(
                          "CARE-\nPANION",
                          textAlign: TextAlign.left,
                          style: GoogleFonts.nunito(
                            color: const Color(0xFFCA5000),
                            fontSize: 47,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            height: 0.74,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "A Voice-Driven Reminder App for\nWellness and Daily Care",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      color: const Color(0xFFCA5000),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Column(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCA5000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  minimumSize: const Size(220, 55),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, "/signin");
                },
                child: Text(
                  "SIGN IN",
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCA5000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  minimumSize: const Size(220, 55),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, "/register_email");
                },
                child: Text(
                  "SIGN UP",
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
