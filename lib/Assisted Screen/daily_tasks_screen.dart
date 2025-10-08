import 'package:flutter/material.dart';

class DailyTasksScreen extends StatelessWidget {
  final DateTime selectedDate;

  const DailyTasksScreen({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    String formattedDate =
        "${_monthNames[selectedDate.month - 1].toUpperCase()} ${selectedDate.day}";

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("TO DO"),
                    _taskCard(
                      "MEDICATION",
                      "7:30 AM",
                      "Drink Zykast",
                      const Color(0xFFB3E5FC),
                    ),

                    const SizedBox(height: 16),

                    _sectionTitle("DONE"),
                    _taskCard(
                      "MEDICATION",
                      "7:00 AM",
                      "Drink Glipten",
                      const Color(0xFFB9F6CA),
                    ),
                    _taskCard(
                      "WALK",
                      "7:15 AM",
                      "Walk for 5 mins",
                      const Color(0xFFB9F6CA),
                    ),

                    const SizedBox(height: 16),

                    _sectionTitle("SKIP"),
                    _taskCard(
                      "READ BOOK",
                      "6:30 PM",
                      "-",
                      const Color(0xFFFFCCBC),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Section Title ---
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          letterSpacing: 1.2,
          color: Colors.black87,
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
