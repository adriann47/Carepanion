import 'package:flutter/material.dart';
// Keep alert as a modal confirmation; return to prior screen on pop

class EmergencyAlertScreen extends StatelessWidget {
  const EmergencyAlertScreen({
    super.key,
    required this.assistedName,
    required this.isGuardianView,
  });

  final String assistedName;
  final bool isGuardianView;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.redAccent,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.notifications_active,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 30),
              Text(
                "EMERGENCY",
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "${assistedName.isNotEmpty ? assistedName : 'User'} HAS PRESSED THE\nEMERGENCY BUTTON",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 50),

              /// --- Button (STOP for Assisted, CONFIRM for Guardian) ---
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
                child: Text(
                  isGuardianView ? "CONFIRM" : "STOP",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
