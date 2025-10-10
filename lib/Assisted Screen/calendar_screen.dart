import 'package:flutter/material.dart';
import 'daily_tasks_screen.dart';
import 'tasks_screen.dart';
import 'profile_screen.dart';
import 'emergency_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate = DateTime.now();

  int _currentIndex = 1;

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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TasksScreen()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const EmergencyScreen()),
      );
    } else if (index == 3) {
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
      body: Column(
        children: [
          /// --- HEADER (Pink bar or you can replace with an image later) ---
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

          /// --- MAIN CONTENT ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DATE',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
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
                      /// --- MONTH & YEAR DROPDOWNS ---
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
                                _focusedMonth =
                                    DateTime(year, newMonth, _focusedMonth.day);
                                _selectedDate =
                                    DateTime(year, newMonth, _focusedMonth.day);
                              });
                            },
                          ),

                          /// --- YEAR DROPDOWN ---
                          DropdownButton<int>(
                            value: year,
                            underline: const SizedBox.shrink(),
                            items: List.generate(
                              20, // range: 10 years back + 10 years forward
                              (i) {
                                int y = DateTime.now().year - 10 + i;
                                return DropdownMenuItem<int>(
                                  value: y,
                                  child: Text(
                                    '$y',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                            onChanged: (int? newYear) {
                              if (newYear == null) return;
                              setState(() {
                                _focusedMonth =
                                    DateTime(newYear, month, _focusedMonth.day);
                                _selectedDate =
                                    DateTime(newYear, month, _focusedMonth.day);
                              });
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      /// --- WEEKDAY LABELS ---
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

                      /// --- CALENDAR GRID ---
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
                                        fontWeight:
                                            isToday ? FontWeight.w700 : null,
                                        color: isToday
                                            ? Colors.black
                                            : Colors.black87,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      /// --- BOTTOM NAVIGATION BAR ---
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
          _navItem(Icons.calendar_today, 'Menu',
              isSelected: _currentIndex == 1),
          _navItem(Icons.warning_amber_rounded, 'Alert',
              isSelected: _currentIndex == 2),
          _navItem(Icons.person, 'Profile', isSelected: _currentIndex == 3),
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
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? Colors.pink.shade100 : const Color(0xFFE0E0E0),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 32,
            color: isSelected ? Colors.pink : Colors.black87,
          ),
        ),
      ),
    );
  }
}
