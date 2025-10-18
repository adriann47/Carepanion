import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tasks_screen_regular.dart';
import 'calendar_screen_regular.dart';
import 'companion_list.dart';
import 'profile_screen_regular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:softeng/data/profile_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key, this.notifications});
  final List<Map<String, dynamic>>? notifications;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> with WidgetsBindingObserver {
  int _currentIndex = 3; // Notifications tab selected
  Map<String, String> _assistedUserNames = {};
  Map<String, Map<String, dynamic>> _taskDetails = {};
  bool _isLoadingNames = false;
  Set<String> _loadingUserIds = {};
  Set<String> _loadingTaskIds = {};
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  List<Map<String, dynamic>> _currentNotifications = [];

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kDebugMode) {
      print('NotificationScreen: initState called');
    }
    // Load assisted user names when screen initializes
    _loadAssistedUserNames();
    // Start listening to notifications
    _startNotificationStream();
    // Listen for auth state changes
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn || event.event == AuthChangeEvent.tokenRefreshed) {
        if (mounted) {
          _startNotificationStream();
        }
      }
    });

    // Test real-time connection
    _testRealtimeConnection();

    // Fallback: refresh every 10 seconds to ensure notifications are current
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _refreshNotificationsSilently();
      }
    });
  }

  void _testRealtimeConnection() async {
    final supabase = Supabase.instance.client;
    try {
      // Test if we can query the publication tables
      final result = await supabase.rpc('get_publication_tables');
      if (kDebugMode) {
        print('Publication tables: $result');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Cannot query publication tables: $e');
      }
    }

    // Test direct query to see if completed/skipped tasks exist
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid != null) {
        final completedTasks = await supabase
            .from('tasks')
            .select('*')
            .eq('created_by', uid)
            .or('status.eq.done,status.eq.skip,status.eq.skipped')
            .order('created_at', ascending: false)
            .limit(5);

        if (kDebugMode) {
          print('Direct task completion/skipped query result: ${completedTasks.length} items');
          if (completedTasks.isNotEmpty) {
            print('Most recent completed/skipped task: ${completedTasks.first}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Direct task completion/skipped query failed: $e');
      }
    }

    // Also test if we can see any tasks at all
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid != null) {
        final allTasks = await supabase
            .from('tasks')
            .select('*')
            .limit(10);

        if (kDebugMode) {
          print('All tasks query result: ${allTasks.length} items');
          if (allTasks.isNotEmpty) {
            print('Sample task: ${allTasks.first}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('All tasks query failed: $e');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (kDebugMode) {
      print('NotificationScreen: App lifecycle state changed to: $state');
    }
    // Refresh notifications when app comes back to foreground
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshNotifications();
    }
  }

  Future<void> _refreshNotificationsSilently() async {
    if (kDebugMode) {
      print('Performing silent task completion notification refresh');
    }

    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser?.id;

    if (uid == null) {
      if (kDebugMode) {
        print('Cannot refresh notifications silently: no user ID');
      }
      return;
    }

    try {
      // Do a direct query to get the latest completed/skipped tasks created by this guardian
      final directData = await supabase
          .from('tasks')
          .select('*')
          .eq('created_by', uid)
          .or('status.eq.done,status.eq.skip,status.eq.skipped')
          .order('created_at', ascending: false)
          .limit(50); // Get more for better coverage

      if (mounted) {
        // Convert task data to notification format
        final notifications = directData.map((task) {
          final status = task['status']?.toString().toLowerCase() ?? '';
          final action = status == 'done' ? 'done' : 'skipped';
          return {
            'id': task['id'],
            'task_id': task['id'].toString(),
            'assisted_id': task['user_id'], // The assisted user who completed/skipped the task
            'guardian_id': uid,
            'user_id': task['user_id'],
            'title': task['title'] ?? (status == 'done' ? 'Task Completed' : 'Task Skipped'),
            'scheduled_at': task['start_at'],
            'action': action,
            'action_at': task['created_at'] ?? DateTime.now().toIso8601String(),
            'is_read': false,
            'due_date': task['due_date'],
            'description': task['description'],
          };
        }).toList();

        // Filter to show notifications from the last 7 days
        final filteredData = notifications
            .where((notification) {
              final actionAt = DateTime.tryParse(notification['action_at']?.toString() ?? '');
              if (actionAt == null) return false;
              final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
              return actionAt.isAfter(sevenDaysAgo);
            })
            .toList();

        if (kDebugMode) {
          print('Silent refresh: ${filteredData.length} completed task notifications found');
        }

        setState(() {
          _currentNotifications = filteredData;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during silent notification refresh: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _streamSubscription?.cancel();
    _authSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startNotificationStream() async {
    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser?.id;

    if (kDebugMode) {
      print('NotificationScreen: _startNotificationStream called, uid: $uid');
    }

    if (uid == null) {
      if (kDebugMode) {
        print('Cannot start notification stream: no user ID');
      }
      return;
    }

    _streamSubscription?.cancel();
    if (kDebugMode) {
      print('Starting task completion notification stream for guardian: $uid');
    }

    // First, do an initial query to get existing completed and skipped tasks
    await _loadInitialNotifications(uid);

    // Then set up the stream for real-time updates
    _streamSubscription = supabase
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('created_by', uid)
        .order('created_at', ascending: false)
        .listen(
          (data) {
            if (kDebugMode) {
              print('Raw task data received: ${data.length} items');
              if (data.isNotEmpty) {
                print('First task: ${data.first}');
              }
            }

            if (mounted) {
              // Filter for tasks with status 'done' or 'skip'/'skipped' and convert to notification format
              final relevantTasks = data.where((task) {
                final status = task['status']?.toString().toLowerCase() ?? '';
                return status == 'done' || status == 'skip' || status == 'skipped';
              }).toList();

              final notifications = relevantTasks.map((task) {
                final status = task['status']?.toString().toLowerCase() ?? '';
                final action = status == 'done' ? 'done' : 'skipped';
                return {
                  'id': task['id'],
                  'task_id': task['id'].toString(),
                  'assisted_id': task['user_id'], // The assisted user who completed/skipped the task
                  'guardian_id': uid,
                  'user_id': task['user_id'],
                  'title': task['title'] ?? (status == 'done' ? 'Task Completed' : 'Task Skipped'),
                  'scheduled_at': task['start_at'],
                  'action': action,
                  'action_at': task['created_at'] ?? DateTime.now().toIso8601String(),
                  'is_read': false,
                  'due_date': task['due_date'],
                  'description': task['description'],
                };
              }).toList();

              // Filter to show notifications from the last 7 days
              final filteredNotifications = notifications
                  .where((notification) {
                    final actionAt = DateTime.tryParse(notification['action_at']?.toString() ?? '');
                    if (actionAt == null) return false;
                    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
                    return actionAt.isAfter(sevenDaysAgo);
                  })
                  .toList();

              if (kDebugMode) {
                print('Filtered completed/skipped tasks: ${filteredNotifications.length} items');
              }

              setState(() {
                _currentNotifications = filteredNotifications;
              });

              if (kDebugMode) {
                print('Task completion notifications updated: ${filteredNotifications.length} notifications');
              }
            }
          },
          onError: (error) {
            if (kDebugMode) {
              print('Task completion notification stream error: $error');
            }
            // Retry after a delay
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                _startNotificationStream();
              }
            });
          },
          onDone: () {
            if (kDebugMode) {
              print('Task completion notification stream done');
            }
          },
        );

    if (kDebugMode) {
      print('Task completion notification stream subscription created');
    }
  }

  Future<void> _loadInitialNotifications(String uid) async {
    if (kDebugMode) {
      print('Loading initial notifications for guardian: $uid');
    }

    try {
      final supabase = Supabase.instance.client;

      // Get all completed and skipped tasks created by this guardian
      final relevantTasks = await supabase
          .from('tasks')
          .select('*')
          .eq('created_by', uid)
          .or('status.eq.done,status.eq.skip,status.eq.skipped')
          .order('created_at', ascending: false)
          .limit(50); // Get more for better coverage

      if (kDebugMode) {
        print('Initial query returned ${relevantTasks.length} completed/skipped tasks');
        if (relevantTasks.isNotEmpty) {
          print('Sample task: ${relevantTasks.first}');
        }
      }

      if (mounted) {
        // Convert task data to notification format
              final notifications = relevantTasks.map((task) {
                final status = task['status']?.toString().toLowerCase() ?? '';
                final action = status == 'done' ? 'done' : 'skipped';
                return {
                  'id': task['id'],
                  'task_id': task['id'].toString(),
                  'assisted_id': task['user_id'], // The assisted user who completed/skipped the task
                  'guardian_id': uid,
                  'user_id': task['user_id'],
                  'title': task['title'] ?? (status == 'done' ? 'Task Completed' : 'Task Skipped'),
                  'scheduled_at': task['start_at'],
                  'action': action,
                  'action_at': task['created_at'] ?? DateTime.now().toIso8601String(),
                  'is_read': false,
                  'due_date': task['due_date'],
                  'description': task['description'],
                };
              }).toList();        // Filter to show notifications from the last 7 days
        final filteredNotifications = notifications
            .where((notification) {
              final actionAt = DateTime.tryParse(notification['action_at']?.toString() ?? '');
              if (actionAt == null) return false;
              final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
              return actionAt.isAfter(sevenDaysAgo);
            })
            .toList();

        if (kDebugMode) {
          print('Initial notifications loaded: ${filteredNotifications.length} items after filtering');
          if (filteredNotifications.isNotEmpty) {
            print('First notification: ${filteredNotifications.first}');
          }
        }

        setState(() {
          _currentNotifications = filteredNotifications;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading initial notifications: $e');
        print('Error details: ${e.toString()}');
      }
    }
  }

  Future<void> _loadAssistedUserNames() async {
    setState(() => _isLoadingNames = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoadingNames = false);
        return;
      }

      // Get all assisted users for this guardian
      final assistedUsers = await ProfileService.fetchAssistedsForGuardian(client, guardianUserId: user.id);

      // Create a map of user ID to display name
      final names = <String, String>{};
      for (final user in assistedUsers) {
        final userId = user['id'] as String;
        final fullName = user['fullname'] as String? ?? user['email'] as String? ?? 'Unknown User';
        names[userId] = fullName;
      }

      if (mounted) {
        setState(() {
          _assistedUserNames = names;
          _isLoadingNames = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading assisted user names: $e');
      }
      if (mounted) {
        setState(() => _isLoadingNames = false);
      }
    }
  }

  Future<void> _loadUserNameIfNeeded(String userId) async {
    if (_assistedUserNames.containsKey(userId) || _loadingUserIds.contains(userId)) {
      return;
    }

    _loadingUserIds.add(userId);
    try {
      final client = Supabase.instance.client;
      final userData = await client
          .from('profiles')
          .select('fullname, email')
          .eq('id', userId)
          .maybeSingle();

      if (userData != null && mounted) {
        final fullName = userData['fullname'] as String? ?? userData['email'] as String? ?? 'Unknown User';
        setState(() {
          _assistedUserNames[userId] = fullName;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user name for $userId: $e');
      }
    } finally {
      _loadingUserIds.remove(userId);
    }
  }

  Future<void> _loadTaskDetailsIfNeeded(String taskId) async {
    if (_taskDetails.containsKey(taskId) || _loadingTaskIds.contains(taskId)) {
      return;
    }

    _loadingTaskIds.add(taskId);
    try {
      final client = Supabase.instance.client;
      final taskData = await client
          .from('tasks')
          .select('id, due_date, description')
          .eq('id', taskId)
          .maybeSingle();

      if (taskData != null && mounted) {
        setState(() {
          _taskDetails[taskId] = {
            'due_date': taskData['due_date'],
            'description': taskData['description'],
          };
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading task details for $taskId: $e');
      }
    } finally {
      _loadingTaskIds.remove(taskId);
    }
  }

  Future<void> _refreshNotifications() async {
    // Clear cached data and reload assisted user names
    setState(() {
      _assistedUserNames.clear();
      _taskDetails.clear();
      _currentNotifications.clear();
    });
    await _loadAssistedUserNames();
    // Restart the notification stream
    _startNotificationStream();

    // Also do a direct query to check if completed/skipped tasks exist
    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser?.id;
    if (uid != null && kDebugMode) {
      try {
        final directData = await supabase
            .from('tasks')
            .select('*')
            .eq('created_by', uid)
            .or('status.eq.done,status.eq.skip,status.eq.skipped')
            .order('created_at', ascending: false)
            .limit(10);

        print('Direct task completion/skipped query result: ${directData.length} completed/skipped tasks');
        if (directData.isNotEmpty) {
          print('Latest task: ${directData.first}');
        }
      } catch (e) {
        print('Direct task completion/skipped query error: $e');
      }
    }
  }



  void _onTabTapped(int index) {
    if (kDebugMode) {
      print('NotificationScreen: _onTabTapped called with index $index, current index $_currentIndex');
    }

    if (_currentIndex == index) {
      // Already on this tab, just refresh if it's notifications
      if (index == 3) {
        _refreshNotifications();
      }
      return;
    }

    setState(() => _currentIndex = index);

    Widget destinationScreen;
    switch (index) {
      case 0:
        destinationScreen = const TasksScreenRegular();
        break;
      case 1:
        destinationScreen = const CalendarScreenRegular();
        break;
      case 2:
        destinationScreen = const CompanionListScreen();
        break;
      case 3:
        // Stay on notifications screen
        return;
      case 4:
        destinationScreen = const ProfileScreen();
        break;
      default:
        return;
    }

    if (kDebugMode) {
      print('NotificationScreen: Navigating to ${destinationScreen.runtimeType}');
    }

    // Replace current route with the destination screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => destinationScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser?.id;

    final titleTextStyle = GoogleFonts.nunito(
      color: Colors.pink,
      fontSize: 26,
      fontWeight: FontWeight.w800,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.pink),
            onPressed: _refreshNotifications,
            tooltip: 'Refresh notifications',
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('NOTIFICATIONS', style: titleTextStyle),
            const SizedBox(height: 16),
            Expanded(
              child: widget.notifications != null
                  ? _NotificationList(
                      notifications: widget.notifications!,
                      assistedUserNames: _assistedUserNames,
                      taskDetails: _taskDetails,
                      onLoadUserName: _loadUserNameIfNeeded,
                      onLoadTaskDetails: _loadTaskDetailsIfNeeded,
                    )
                  : uid == null
                      ? const Center(child: Text('Please sign in to view notifications.'))
                      : _currentNotifications.isEmpty && _isLoadingNames
                          ? const Center(child: CircularProgressIndicator())
                          : _currentNotifications.isEmpty
                              ? RefreshIndicator(
                                  onRefresh: _refreshNotifications,
                                  child: const Center(child: Text('No notifications yet. Pull to refresh.')),
                                )
                              : RefreshIndicator(
                                  onRefresh: _refreshNotifications,
                                  child: _NotificationList(
                                    notifications: _currentNotifications,
                                    assistedUserNames: _assistedUserNames,
                                    taskDetails: _taskDetails,
                                    onLoadUserName: _loadUserNameIfNeeded,
                                    onLoadTaskDetails: _loadTaskDetailsIfNeeded,
                                  ),
                                ),
            ),
          ],
        ),
      ),

      // --- ✅ Bottom Navigation Bar ---
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
          _navItem(Icons.family_restroom, 'Companions', isSelected: _currentIndex == 2),
          _navItem(Icons.notifications, 'Notifications', isSelected: _currentIndex == 3),
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
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({
    required this.notifications,
    required this.assistedUserNames,
    required this.taskDetails,
    required this.onLoadUserName,
    required this.onLoadTaskDetails,
  });

  final List<Map<String, dynamic>> notifications;
  final Map<String, String> assistedUserNames;
  final Map<String, Map<String, dynamic>> taskDetails;
  final Future<void> Function(String) onLoadUserName;
  final Future<void> Function(String) onLoadTaskDetails;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final n = notifications[i];
        return _NotificationTile(
          notification: n,
          assistedUserNames: assistedUserNames,
          taskDetails: taskDetails,
          onLoadUserName: onLoadUserName,
          onLoadTaskDetails: onLoadTaskDetails,
        );
      },
    );
  }
}

class _NotificationTile extends StatefulWidget {
  const _NotificationTile({
    required this.notification,
    required this.assistedUserNames,
    required this.taskDetails,
    required this.onLoadUserName,
    required this.onLoadTaskDetails,
  });

  final Map<String, dynamic> notification;
  final Map<String, String> assistedUserNames;
  final Map<String, Map<String, dynamic>> taskDetails;
  final Future<void> Function(String) onLoadUserName;
  final Future<void> Function(String) onLoadTaskDetails;

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  @override
  void initState() {
    super.initState();
    // Load data lazily when the tile is first created
    final assistedId = widget.notification['assisted_id']?.toString();

    if (assistedId != null && !widget.assistedUserNames.containsKey(assistedId)) {
      widget.onLoadUserName(assistedId);
    }

    // No need to load task details since they're already included in the notification
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final isDone = (n['action'] ?? '') == 'done';
    final isSkipped = (n['action'] ?? '') == 'skipped';
    final title = (n['title'] ?? 'Task').toString();
    final assistedId = n['assisted_id']?.toString() ?? '';
    final assistedName = widget.assistedUserNames[assistedId] ?? 'Loading...';

    final actionAt = DateTime.tryParse((n['action_at'] ?? '').toString())?.toLocal();
    final timeString = actionAt != null ? TimeOfDay.fromDateTime(actionAt).format(context) : '';

    // Get task details directly from notification (already included)
    final dueDate = n['due_date']?.toString();
    final description = n['description']?.toString();

    // Format deadline
    String deadlineString = 'No deadline';
    if (dueDate != null && dueDate.isNotEmpty) {
      try {
        final date = DateTime.parse(dueDate);
        deadlineString = DateFormat('MMM d, yyyy').format(date);
      } catch (_) {}
    }

    // Get notes (description)
    final notes = description ?? 'No notes';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with status and time
          Row(
            children: [
              // Status indicator - Check for done, X for skipped
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDone
                      ? Colors.green.withOpacity(0.1)
                      : isSkipped
                          ? Colors.red.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDone ? Icons.check_circle : Icons.cancel,
                  color: isDone ? Colors.green : Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Time
              Text(
                timeString,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Assisted user name
          Text(
            assistedName,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(height: 8),

          // Task title
          Text(
            title,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E2A36),
            ),
          ),
          const SizedBox(height: 12),

          // Deadline and Notes in a row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Deadline
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEADLINE',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      deadlineString,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2D2D2D),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Notes
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NOTES',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notes,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2D2D2D),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}