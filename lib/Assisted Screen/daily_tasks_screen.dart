import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:softeng/services/task_service.dart';
import '../Regular Screen/edit_task.dart';

class DailyTasksScreen extends StatefulWidget {
  final DateTime selectedDate;

  const DailyTasksScreen({super.key, required this.selectedDate});

  @override
  State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen> {
  @override
  Widget build(BuildContext context) {
    String formattedDate =
        "${_monthNames[widget.selectedDate.month - 1].toUpperCase()} ${widget.selectedDate.day}";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F3ED),
      body: SafeArea(
        child: Column(
          children: [
            // --- Back Button ---
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            // --- Centered Date ---
            Text(
              formattedDate,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // --- Scrollable Task Sections ---
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: TaskService.getTasksForDate(widget.selectedDate),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error loading tasks: ${snapshot.error}'));
                  }
                  final tasks = snapshot.data ?? [];
                  if (tasks.isEmpty) {
                    return const Center(child: Text('No tasks for this day'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final t = tasks[index];
                      final String title = (t['title'] ?? '').toString();
                      final String category = (t['category'] ?? 'OTHER').toString().toUpperCase();
                      final String description = (t['description'] ?? '').toString();
                      final String timeLabel = _formatTimeRange(t['start_at'], t['end_at']);
                      final Color color = _categoryColor(category);

                      return InkWell(
                        onTap: () async {
                          final changed = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditTaskScreen(task: t),
                            ),
                          );
                          if (changed == true) {
                            setState(() {});
                          }
                        },
                        child: _taskCard(
                          category,
                          timeLabel,
                          title + (description.isNotEmpty ? " — $description" : ""),
                          color,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Task Card (Full Width) ---
  Widget _taskCard(
    String task,
    String time,
    String note,
    Color backgroundColor,
  ) {
    return Container(
      width: double.infinity, // ✅ Full width of the screen
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black54, // ✅ gray
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Time: $time",
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          Text(
            "Note: $note",
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  String _formatTimeRange(dynamic startIso, dynamic endIso) {
    String fmt(dynamic iso) {
      if (iso == null) return '';
      try {
        final dt = DateTime.parse(iso.toString()).toLocal();
        return DateFormat('h:mm a').format(dt);
      } catch (_) {
        return '';
      }
    }

    final s = fmt(startIso);
    final e = fmt(endIso);
    if (s.isEmpty && e.isEmpty) return 'All day';
    if (s.isNotEmpty && e.isEmpty) return s;
    if (s.isEmpty && e.isNotEmpty) return e;
    return '$s - $e';
  }

  Color _categoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'MEDICATION':
        return const Color(0xFFB3E5FC);
      case 'EXERCISE':
      case 'WALK':
        return const Color(0xFFB9F6CA);
      case 'OTHER':
      default:
        return const Color(0xFFFFCCBC);
    }
  }

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
}
