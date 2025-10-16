import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Your screens
import 'screen/welcome_screen.dart';
import 'screen/signin_screen.dart';
import 'screen/registration_email_screen.dart';
import 'screen/registration_phone_screen.dart';
import 'screen/verify_email_screen.dart';
import 'screen/google_registration.dart';
import 'screen/role_selection_screen.dart';
import 'Assisted Screen/guardian_input_screen.dart';
import 'Assisted Screen/tasks_screen.dart';
import 'Assisted Screen/profile_screen.dart';
import 'Assisted Screen/notification.dart';
import 'Assisted Screen/account.dart';
import 'Assisted Screen/settings.dart';
import 'data/profile_service.dart';
import 'services/navigation.dart';
import 'services/reminder_service.dart';
import 'services/emergency_service.dart';
import 'services/notification_prefs.dart';
import 'services/notification_service.dart';
import 'services/guardian_request_service.dart';
import 'Regular Screen/tasks_screen_regular.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Supabase with your project's URL and anon key
  await Supabase.initialize(
    url: 'https://eyalgnlsdseuvmmtgefk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV5YWxnbmxzZHNldXZtbXRnZWZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk5ODEwMjYsImV4cCI6MjA3NTU1NzAyNn0.IWCEqWYR-WaXzMlCCZkmmPHuP_KjHlSA4Zyhlfj8wNM',
  );

  // Pin profile table name to match your schema
  ProfileService.setPreferredTable('profile');

  // Load persisted notification preferences and initialize local notifications
  await NotificationPreferences.init();
  await NotificationService.init();

  // Listen for native reminder payloads via MethodChannel (for full-screen Activity forwarding)
  const channel = MethodChannel('carepanion.reminder');
  channel.setMethodCallHandler((call) async {
    if (call.method == 'showReminder' && call.arguments is String) {
      final taskId = call.arguments as String;
      // Debug log so we can see when native forwards a reminder
      // (appears in Flutter logs)
      // ignore: avoid_print
      print('MethodChannel showReminder received: $taskId');
      if (taskId.isNotEmpty) {
        await ReminderService.showPopupForTaskId(taskId);
      }
    }
  });

  // Also ask native layer for any saved reminder payload (fallback for cold-start)
  try {
    final saved = await channel.invokeMethod<String>('popSavedReminder');
    if (saved != null && saved.isNotEmpty) {
      // Try to extract task_id and show popup
      final idMatch = RegExp('"task_id"\s*:\s*"([^"]+)"').firstMatch(saved);
      if (idMatch != null) {
        final taskId = idMatch.group(1);
        if (taskId != null && taskId.isNotEmpty) {
          // ignore: avoid_print
          print('Native popSavedReminder returned taskId=$taskId');
          await ReminderService.showPopupForTaskId(taskId);
        }
      }
    }
  } catch (e) {
    // ignore errors — best-effort
  }

  // Start global auth listener so OAuth redirects (especially on web) land back in-app
  _setupGlobalAuthListener();

  runApp(const CarePanionApp());
}

// Global navigator key to allow navigation from auth-state listener
// Use shared global nav key so services can present dialogs from anywhere
// (defined in services/navigation.dart)
final GlobalKey<NavigatorState> _navKey = navKey;
StreamSubscription<AuthState>? _authSub;

void _setupGlobalAuthListener() {
  final supa = Supabase.instance.client;
  _authSub?.cancel();
  _authSub = supa.auth.onAuthStateChange.listen((data) async {
    if (data.event == AuthChangeEvent.signedIn) {
      final user = supa.auth.currentUser;
      final provider =
          (user?.appMetadata != null ? user!.appMetadata['provider'] : '')
              ?.toString();
      // If signed in via Google, take the user to GoogleRegistration
      if (provider == 'google') {
        _navKey.currentState?.pushNamedAndRemoveUntil(
          '/google_registration',
          (route) => false,
        );
      }
      // Start guardian request listener for signed-in users
      GuardianRequestService().start();
    } else if (data.event == AuthChangeEvent.signedOut) {
      // Stop guardian request listener on sign out
      GuardianRequestService().stop();
    }
  });
}

class CarePanionApp extends StatelessWidget {
  const CarePanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Start global reminder service once MaterialApp builds
    // (safe to call multiple times - it restarts its timer)
    ReminderService.start();
    // Start emergency listener for guardian users
    EmergencyService.start();
    // Start guardian request listener if user is already signed in
    if (Supabase.instance.client.auth.currentUser != null) {
      GuardianRequestService().start();
    }

    // If the app was launched from a notification, show the reminder popup.
    // We purposely do this after starting services so navKey is available.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final payload = await NotificationService.getInitialPayload();
        if (payload != null && payload.isNotEmpty) {
          try {
            final data = Uri.decodeFull(payload);
            // payload is JSON like {"task_id":"..."}
            final m = data;
            // Delegate to ReminderService which will fetch task and show dialog
            // Ignore errors — best-effort
            final idMatch = RegExp('"task_id"\s*:\s*"([^"]+)"').firstMatch(m);
            if (idMatch != null) {
              final taskId = idMatch.group(1);
              if (taskId != null && taskId.isNotEmpty) {
                await ReminderService.showPopupForTaskId(taskId);
              }
            }
          } catch (_) {}
        }
      } catch (_) {}
    });

    return MaterialApp(
      navigatorKey: _navKey,
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
        "/google_registration": (context) => GoogleRegistration(),
        "/role_selection": (context) => const RoleSelectionScreen(),
        "/guardian_input": (context) => const GuardianInputScreen(),
        "/tasks": (context) => const TasksScreen(),
        "/tasks_regular": (context) => const TasksScreenRegular(),
        "/profile": (context) => const ProfileScreen(),
        "/settings": (context) => const SettingsScreen(),
        "/notifications": (context) => NotificationPage(),
        "/account": (context) => const AccountPage(),
      },
    );
  }
}

