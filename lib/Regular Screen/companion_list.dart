import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/profile_service.dart';
import 'companion_detail.dart';
import 'tasks_screen_regular.dart';
import 'calendar_screen_regular.dart';
import 'notification_screen.dart'; // ✅ Added this import
import 'profile_screen_regular.dart';
class CompanionListScreen extends StatefulWidget {
  const CompanionListScreen({super.key});

  @override
  State<CompanionListScreen> createState() => _CompanionListScreenState();
}

class _CompanionListScreenState extends State<CompanionListScreen> {
  int _currentIndex = 2; // Companions tab selected
  bool _isLoading = true;
  List<Map<String, dynamic>> _assisteds = [];
  RealtimeChannel? _agChannel;
  RealtimeChannel? _profileChannel;

  @override
  void initState() {
    super.initState();
    _loadAssisteds();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    final client = Supabase.instance.client;
    final gid = client.auth.currentUser?.id;
    if (gid == null) return;

    // Listen for assisted_guardians changes for this guardian
    _agChannel?.unsubscribe();
    _agChannel = client
        .channel('public:assisted_guardians:guardian:$gid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'assisted_guardians',
        callback: (payload) async {
          try {
            final newRec = payload.newRecord as Map<String, dynamic>?;
            // Debug log: print payload (helps in dev builds)
            // ignore: avoid_print
            print('assisted_guardians INSERT payload: $newRec');

            if (newRec?['guardian_id']?.toString() == gid) {
              final assistedId = newRec?['assisted_id']?.toString();
              if (assistedId != null && assistedId.isNotEmpty) {
                // Show a short snackbar so the guardian sees something even if the dialog fails
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New companion request received')),
                  );
                }

                // Prompt guardian to accept or reject the request
                final prof = await ProfileService.fetchProfile(client, userId: assistedId);
                if (!mounted) return;
                final name = (prof?['fullname'] ?? prof?['name'] ?? 'Assisted') as String;
                // showDialog must be called from the UI thread
                if (mounted) {
                  try {
                    await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Companion request'),
                        content: Text('$name requested you as guardian. Accept?'),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              // mark as rejected
                              await client.from('assisted_guardians').update({'status': 'rejected'}).eq('assisted_id', assistedId).eq('guardian_id', gid);
                              _loadAssisteds();
                            },
                            child: const Text('Reject'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              // mark as accepted
                              await client.from('assisted_guardians').update({'status': 'accepted'}).eq('assisted_id', assistedId).eq('guardian_id', gid);
                              // update profile to set guardian_id for the assisted user
                              await client.from('profile').update({'guardian_id': gid}).eq('id', assistedId);
                              _loadAssisteds();
                            },
                            child: const Text('Accept'),
                          ),
                        ],
                      ),
                    );
                  } catch (ex) {
                    // ignore: avoid_print
                    print('Error showing companion request dialog: $ex');
                    // fallback: ensure assisteds list refreshed
                    _loadAssisteds();
                  }
                }
              } else {
                _loadAssisteds();
              }
            }
          } catch (e) {
            // ignore: avoid_print
            print('Error handling assisted_guardians insert payload: $e');
            _loadAssisteds();
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'assisted_guardians',
        callback: (payload) {
          final oldRec = payload.oldRecord as Map<String, dynamic>?;
          if (oldRec?['guardian_id']?.toString() == gid) {
            final assistedId = oldRec?['assisted_id']?.toString();
            if (assistedId != null && assistedId.isNotEmpty) {
              setState(() => _assisteds =
                  _assisteds.where((e) => e['id']?.toString() != assistedId).toList());
            } else {
              _loadAssisteds();
            }
          }
        },
      )
      ..subscribe();

    // Also listen for legacy profile updates where assisted rows change guardian_id to this guardian
    _profileChannel?.unsubscribe();
    _profileChannel = client
        .channel('public:profile_guardian:guardian:$gid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'profile',
        callback: (payload) {
          final newRec = payload.newRecord as Map<String, dynamic>?;
          final oldRec = payload.oldRecord as Map<String, dynamic>?;
          final newG = newRec?['guardian_id']?.toString();
          final oldG = oldRec?['guardian_id']?.toString();
          if (newG == gid || oldG == gid) {
            _loadAssisteds();
          }
        },
      )
      ..subscribe();
  }

  Future<void> _loadAssisteds() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final supabase = Supabase.instance.client;
      final guardianId = supabase.auth.currentUser?.id;
      if (guardianId != null) {
        final rows = await ProfileService.fetchAssistedsForGuardian(supabase, guardianUserId: guardianId);
        setState(() => _assisteds = rows);
      } else {
        setState(() => _assisteds = []);
      }
    } catch (_) {
      setState(() => _assisteds = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);

    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TasksScreenRegular()),
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CalendarScreenRegular()),
      );
    } else if (index == 3) {
      // ✅ Go to Notification Screen when Notification icon clicked
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => NotificationScreen(notifications: const [])),
      );
    }
    else if (index == 4) {
      // ✅ Go to Notification Screen when Notification icon clicked
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // ✅ Removes back button
      ),

      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                "COMPANION",
                style: TextStyle(
                  color: Colors.pink,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              if (_isLoading) const CircularProgressIndicator(),
              if (!_isLoading && _assisteds.isEmpty)
                const Text('No companions found.'),

              if (!_isLoading && _assisteds.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: _assisteds.length,
                    itemBuilder: (context, idx) {
                      final p = _assisteds[idx];
                      final fullname = (p['fullname'] ?? p['full_name'] ?? p['name'])?.toString() ?? 'No name';
                      final avatar = (p['avatar_url'] as String?)?.isNotEmpty == true
                          ? p['avatar_url'] as String
                          : 'assets/logo.jpg';

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CompanionDetailScreen(
                                name: fullname,
                                imagePathOrUrl: avatar,
                                assistedId: p['id'] as String?,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          height: 110,
                          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.lightBlue[100],
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(width: 10),
                              CircleAvatar(
                                radius: 36,
                                backgroundImage: avatar.startsWith('http')
                                    ? NetworkImage(avatar) as ImageProvider
                                    : AssetImage(avatar),
                              ),
                              const SizedBox(width: 30),
                              Text(
                                fullname,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),

      // --- Bottom Navigation Bar ---
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.pink,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: [
          _navItem(Icons.home, 'Home', isSelected: _currentIndex == 0),
          _navItem(Icons.calendar_today, 'Menu', isSelected: _currentIndex == 1),
          _navItem(Icons.family_restroom, 'Companions',
              isSelected: _currentIndex == 2),
          _navItem(Icons.notifications, 'Notifications',
              isSelected: _currentIndex == 3),
          _navItem(Icons.person, 'Profile', isSelected: _currentIndex == 4),
        ],
      ),
    );
  }

  // --- Reusable Nav Item Widget ---
  static BottomNavigationBarItem _navItem(IconData icon, String label,
      {required bool isSelected}) {
    return BottomNavigationBarItem(
      label: label,
      icon: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? Colors.pink.shade100 : const Color(0xFFE0E0E0),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 28,
            color: isSelected ? Colors.pink : Colors.black87,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _agChannel?.unsubscribe();
    _profileChannel?.unsubscribe();
    super.dispose();
  }
}
