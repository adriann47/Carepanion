import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Your screens
import 'screen/welcome_screen.dart';
import 'screen/signin_screen.dart';
import 'screen/registration_email_screen.dart';
import 'screen/registration_phone_screen.dart';
import 'screen/verify_email_screen.dart';
import 'screen/role_selection_screen.dart';
import 'Assisted Screen/guardian_input_screen.dart';
import 'Assisted Screen/tasks_screen.dart';
import 'Assisted Screen/profile_screen.dart';
import 'Assisted Screen/notification.dart';
import 'Assisted Screen/account.dart';
import 'Assisted Screen/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Supabase with your project's URL and anon key
  await Supabase.initialize(
    url: 'https://eyalgnlsdseuvmmtgefk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV5YWxnbmxzZHNldXZtbXRnZWZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk5ODEwMjYsImV4cCI6MjA3NTU1NzAyNn0.IWCEqWYR-WaXzMlCCZkmmPHuP_KjHlSA4Zyhlfj8wNM',
  );

  runApp(const CarePanionApp());
}

class CarePanionApp extends StatelessWidget {
  const CarePanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Care-Panion",
      theme: ThemeData(primarySwatch: Colors.orange),
      initialRoute: "/",
      routes: {
        "/": (context) => const WelcomeScreen(),
        "/signin": (context) => const SignInScreen(),
        "/register_email": (context) => const RegistrationEmailScreen(),
        "/register_phone": (context) => const RegistrationPhoneScreen(),
        "/verify_email": (context) => const VerifyEmailScreen(),
        "/role_selection": (context) => const RoleSelectionScreen(),
        "/guardian_input": (context) => const GuardianInputScreen(),
        "/tasks": (context) => const TasksScreen(),
        "/profile": (context) => const ProfileScreen(),
        "/settings": (context) => const SettingsScreen(),
        "/notifications": (context) => NotificationPage(),
        "/account": (context) => const AccountPage(),
      },
    );
  }
}
