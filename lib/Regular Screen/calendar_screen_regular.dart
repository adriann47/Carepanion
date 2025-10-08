import 'package:flutter/material.dart';
import '../Assisted Screen/daily_tasks_screen.dart';
import 'tasks_screen_regular.dart';
import '../Assisted Screen/profile_screen.dart';
import '../Assisted Screen/emergency_screen.dart';
import '../Regular Screen/add_task.dart';

class CalendarScreenRegular extends StatefulWidget {
  const CalendarScreenRegular({Key? key}) : super(key: key);

  @override
  State<CalendarScreenRegular> createState() => _CalendarScreenRegularState();
}

class _CalendarScreenRegularState extends State<CalendarScreenRegular> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate = DateTime.now();
  int _currentIndex = 1;

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TasksScreenRegular()),
      );
    } else if (index == 1) {
      // Calendar
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const EmergencyScreen()),
      );
    } else if (index == 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Notifications screen coming soon")),
      );
    } else if (index == 4) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int year = _focusedMonth.year;
    final int month = _focusedMonth.month;
    final int daysInMonth = DateTime(year, month + 1, 0).day;
    final int leadingEmpty = DateTime(year, month, 1).weekday % 7;
    final int totalCells = leadingEmpty + daysInMonth;
    final int trailingEmpty = (totalCells % 7 == 0) ? 0 : 7 - (totalCells % 7);
    final int gridCount = totalCells + trailingEmpty;

    final List<DateTime?> gridDates = List.generate(gridCount, (i) {
      final int dayNum = i - leadingEmpty + 1;
      if (dayNum < 1 || dayNum > daysInMonth) return null;
      return DateTime(year, month, dayNum);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F3ED),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Column(
            children: [
              Container(
                height: 120,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5AEB3),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DATE',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              DropdownButton<int>(
                                value: _focusedMonth.month,
                                underline: const SizedBox.shrink(),
                                items: List.generate(
                                  12,
                                  (i) => DropdownMenuItem<int>(
                                    value: i + 1,
                                    child: Text(
                                      _monthNames[i].toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                onChanged: (int? newMonth) {
                                  if (newMonth == null) return;
                                  setState(() {
                                    _focusedMonth = DateTime(year, newMonth, 1);
                                    _selectedDate =
                                        DateTime(year, newMonth, 1);
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
                          GridView.builder(
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

                              final bool isToday =
                                  _isSameDay(date, DateTime.now());
                              final bool isSelected = _selectedDate != null &&
                                  _isSameDay(date, _selectedDate!);

                              return GestureDetector(
                                onTap: () {
                                  setState(() => _selectedDate = date);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          DailyTasksScreen(selectedDate: date),
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
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
          Positioned(
            bottom: 75,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddTaskScreen(
                      selectedDate: _selectedDate ?? DateTime.now(),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Task',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
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
          _navItem(Icons.calendar_today, 'Calendar',
              isSelected: _currentIndex == 1),
          _navItem(Icons.family_restroom, 'Alert',
              isSelected: _currentIndex == 2),
          _navItem(Icons.notifications, 'Notifications',
              isSelected: _currentIndex == 3),
          _navItem(Icons.person, 'Profile', isSelected: _currentIndex == 4),
        ],
      ),
    );
  }

  static BottomNavigationBarItem _navItem(
    IconData icon,
    String label, {
    bool isSelected = false,
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
}
