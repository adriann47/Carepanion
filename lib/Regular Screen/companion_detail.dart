import 'package:flutter/material.dart';
import 'add_task.dart';
import 'tasks_screen_regular.dart';
import 'calendar_screen_regular.dart';
import 'notification_screen.dart';
import '../Assisted Screen/daily_tasks_screen.dart';
import 'profile_screen_regular.dart';

class CompanionDetailScreen extends StatefulWidget {
  final String name;
  final String imagePathOrUrl; // may be an asset path or network URL
  final String? assistedId; // the assisted user's auth id

  const CompanionDetailScreen({
    super.key,
    required this.name,
    required this.imagePathOrUrl,
    this.assistedId,
  });

  @override
  State<CompanionDetailScreen> createState() => _CompanionDetailScreenState();
}

class _CompanionDetailScreenState extends State<CompanionDetailScreen> {
  int _currentIndex = 2; // Companions tab selected
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate = DateTime.now();

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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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
        MaterialPageRoute(
          builder: (context) =>
              CalendarScreenRegular(forUserId: widget.assistedId),
        ),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => NotificationScreen()),
      );
    } else if (index == 4) {
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
        leading: const BackButton(color: Colors.black),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Companion header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.lightBlue[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: widget.imagePathOrUrl.startsWith('http')
                        ? NetworkImage(widget.imagePathOrUrl) as ImageProvider
                        : AssetImage(widget.imagePathOrUrl),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Embedded calendar for this companion
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 6),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // month/year controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      DropdownButton<int>(
                        value: _focusedMonth.month,
                        underline: const SizedBox.shrink(),
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem<int>(
                            value: i + 1,
                            child: Text(_monthNames[i].toUpperCase()),
                          ),
                        ),
                        onChanged: (int? newMonth) {
                          if (newMonth == null) return;
                          setState(() {
                            _focusedMonth = DateTime(
                              _focusedMonth.year,
                              newMonth,
                              1,
                            );
                            _selectedDate = DateTime(
                              _focusedMonth.year,
                              newMonth,
                              1,
                            );
                          });
                        },
                      ),

                      DropdownButton<int>(
                        value: _focusedMonth.year,
                        underline: const SizedBox.shrink(),
                        items: List.generate(5, (i) {
                          int currentYear = DateTime.now().year;
                          int displayYear = currentYear - 2 + i;
                          return DropdownMenuItem<int>(
                            value: displayYear,
                            child: Text(displayYear.toString()),
                          );
                        }),
                        onChanged: (int? newYear) {
                          if (newYear == null) return;
                          setState(() {
                            _focusedMonth = DateTime(
                              newYear,
                              _focusedMonth.month,
                              1,
                            );
                            _selectedDate = DateTime(
                              newYear,
                              _focusedMonth.month,
                              1,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      Expanded(child: Center(child: Text('SU'))),
                      Expanded(child: Center(child: Text('MO'))),
                      Expanded(child: Center(child: Text('TU'))),
                      Expanded(child: Center(child: Text('WE'))),
                      Expanded(child: Center(child: Text('TH'))),
                      Expanded(child: Center(child: Text('FR'))),
                      Expanded(child: Center(child: Text('SA'))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // grid
                  Builder(
                    builder: (context) {
                      final int year = _focusedMonth.year;
                      final int month = _focusedMonth.month;
                      final int daysInMonth = DateTime(year, month + 1, 0).day;
                      final int leadingEmpty =
                          DateTime(year, month, 1).weekday % 7;
                      final int totalCells = leadingEmpty + daysInMonth;
                      final int trailingEmpty = (totalCells % 7 == 0)
                          ? 0
                          : 7 - (totalCells % 7);
                      final int gridCount = totalCells + trailingEmpty;

                      final List<DateTime?> gridDates = List.generate(
                        gridCount,
                        (i) {
                          final int dayNum = i - leadingEmpty + 1;
                          if (dayNum < 1 || dayNum > daysInMonth) return null;
                          return DateTime(year, month, dayNum);
                        },
                      );

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: gridDates.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              childAspectRatio: 1.3,
                            ),
                        itemBuilder: (context, index) {
                          final date = gridDates[index];
                          if (date == null) return const SizedBox.shrink();
                          final bool isToday = _isSameDay(date, DateTime.now());
                          final bool isSelected =
                              _selectedDate != null &&
                              _isSameDay(date, _selectedDate!);
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedDate = date);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DailyTasksScreen(
                                    selectedDate: date,
                                    forUserId: widget.assistedId,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              alignment: Alignment.center,
                              child: isSelected
                                  ? Container(
                                      width: 34,
                                      height: 34,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF5AEB3),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${date.day}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      '${date.day}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isToday
                                            ? FontWeight.w700
                                            : null,
                                        color: isToday
                                            ? Colors.black
                                            : Colors.black87,
                                      ),
                                    ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Add Task button (creates task for assisted user)
            Padding(
              padding: const EdgeInsets.only(
                top: 12.0,
              ), // 🟢 adds space above the button
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddTaskScreen(
                        forUserId: widget.assistedId,
                        selectedDate: _selectedDate,
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.add,
                  color: Colors.white,
                ), // 🟢 consistent icon color
                label: const Text(
                  'Add Task for Companion',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink, // 🟢 button color
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 4, // 🟢 subtle shadow for modern look
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
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
          _navItem(
            Icons.calendar_today,
            'Menu',
            isSelected: _currentIndex == 1,
          ),
          _navItem(
            Icons.family_restroom,
            'Companions',
            isSelected: _currentIndex == 2,
          ),
          _navItem(
            Icons.notifications,
            'Notifications',
            isSelected: _currentIndex == 3,
          ),
          _navItem(Icons.person, 'Profile', isSelected: _currentIndex == 4),
        ],
      ),
    );
  }

  // --- Reusable Nav Item Widget ---
  static BottomNavigationBarItem _navItem(
    IconData icon,
    String label, {
    required bool isSelected,
  }) {
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

  // ✅ Task Card Widget
  // Task list removed — Companion detail now only shows calendar/add task actions.
}
