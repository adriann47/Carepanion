import 'package:flutter/material.dart';
import 'daily_tasks_screen.dart';
import 'tasks_screen.dart';
import 'profile_screen.dart';
import 'emergency_screen.dart';
import 'navbar_assisted.dart'; // ✅ Import your custom navbar

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate = DateTime.now();

  // ignore: unused_field
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

  // ignore: unused_element
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
    // ======= SCALE KNOB (adjust here if you want it a bit bigger/smaller) =======
    const double uiScale = 1.2;

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
          /// --- HEADER (Pink bar) ---
          Container(
            height: 120 * uiScale,
            decoration: const BoxDecoration(
              color: Color(0xFFF5AEB3),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
          ),

          SizedBox(height: 16 * uiScale),

          /// --- MAIN CONTENT ---
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20 * uiScale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DATE',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12 * uiScale,
                  ),
                ),
                SizedBox(height: 8 * uiScale),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16 * uiScale),
                  ),
                  padding: EdgeInsets.all(12 * uiScale),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14 * uiScale,
                                  ),
                                ),
                              ),
                            ),
                            onChanged: (int? newMonth) {
                              if (newMonth == null) return;
                              setState(() {
                                _focusedMonth = DateTime(
                                  year,
                                  newMonth,
                                  _focusedMonth.day,
                                );
                                _selectedDate = DateTime(
                                  year,
                                  newMonth,
                                  _focusedMonth.day,
                                );
                              });
                            },
                          ),

                          /// --- YEAR DROPDOWN ---
                          DropdownButton<int>(
                            value: year,
                            underline: const SizedBox.shrink(),
                            items: List.generate(
                              5, // 2 years before + current year + 2 years after
                              (i) {
                                int currentYear = DateTime.now().year;
                                int y = currentYear - 2 + i;
                                return DropdownMenuItem<int>(
                                  value: y,
                                  child: Text(
                                    '$y',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14 * uiScale,
                                    ),
                                  ),
                                );
                              },
                            ),
                            onChanged: (int? newYear) {
                              if (newYear == null) return;
                              setState(() {
                                _focusedMonth = DateTime(
                                  newYear,
                                  month,
                                  _focusedMonth.day,
                                );
                                _selectedDate = DateTime(
                                  newYear,
                                  month,
                                  _focusedMonth.day,
                                );
                              });
                            },
                          ),
                        ],
                      ),

                      SizedBox(height: 10 * uiScale),

                      /// --- WEEKDAY LABELS ---
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2 * uiScale),
                        child: Row(
                          children: [
                            for (final wd in const [
                              'SU',
                              'MO',
                              'TU',
                              'WE',
                              'TH',
                              'FR',
                              'SA',
                            ])
                              Expanded(
                                child: Center(
                                  child: Text(
                                    wd,
                                    style: TextStyle(
                                      fontSize: 12.5 * uiScale,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8 * uiScale),

                      /// --- CALENDAR GRID ---
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: gridDates.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          // Lower ratio => taller cells (bigger calendar)
                          childAspectRatio: 1.05, // was 1.3
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
                                      width: 36 * uiScale,
                                      height: 36 * uiScale,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF5AEB3),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${date.day}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14 * uiScale,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      '${date.day}',
                                      style: TextStyle(
                                        fontSize: 14 * uiScale,
                                        fontWeight: isToday
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isToday
                                            ? Colors.black
                                            : Colors.black87,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 8 * uiScale),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      /// ✅ Reusable assisted navbar
      bottomNavigationBar: const NavbarAssisted(currentIndex: 1),
    );
  }
}
