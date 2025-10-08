import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({Key? key}) : super(key: key);

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  DateTime? _selectedDate;
  String? _startTime;
  String? _endTime;
  String? _selectedCategory;

  final List<String> _categories = ["MEDICATION", "EXERCISE", "OTHER"];

  Future<void> _pickDate() async {
    DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() {
        final formatted = picked.format(context);
        if (isStart) {
          _startTime = formatted;
        } else {
          _endTime = formatted;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF8F2),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              height: 260,
              decoration: const BoxDecoration(
                color: Color(0xFFF5AEB3),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(60),
                  bottomRight: Radius.circular(60),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button (FIXED)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "TASK",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  const Text(
                    "TITLE",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.only(bottom: 4),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.black87),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.black87),
                            ),
                          ),
                        ),
                      ),
                      const Icon(Icons.edit, size: 16, color: Colors.black54),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Date
                  const Text(
                    "DATE",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              _selectedDate == null
                                  ? ""
                                  : DateFormat('MMM dd, yyyy')
                                      .format(_selectedDate!),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.black54),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _pickDate,
                        child: const CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(0xFFBDE8FF),
                          child: Icon(Icons.calendar_month,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Rest of Form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time Selection
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "START TIME",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _pickTime(true),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    Text(
                                      _startTime ?? "",
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.arrow_drop_down,
                                        color: Colors.black54),
                                  ],
                                ),
                              ),
                            ),
                            Container(height: 1, color: Colors.black87),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "END TIME",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _pickTime(false),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    Text(
                                      _endTime ?? "",
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.arrow_drop_down,
                                        color: Colors.black54),
                                  ],
                                ),
                              ),
                            ),
                            Container(height: 1, color: Colors.black87),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Description
                  const Text(
                    "DESCRIPTION",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.only(bottom: 4),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.black87),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.black87),
                            ),
                          ),
                        ),
                      ),
                      const Icon(Icons.edit, size: 16, color: Colors.black54),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Category
                  const Text(
                    "CATEGORY",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: _categories.map((cat) {
                      Color bg;
                      if (cat == "MEDICATION") {
                        bg = const Color(0xFFFFD6D6);
                      } else if (cat == "EXERCISE") {
                        bg = const Color(0xFFFFEB99);
                      } else {
                        bg = const Color(0xFFBDE8FF);
                      }
                      final isSelected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected
                                ? Border.all(color: Colors.black54, width: 1.2)
                                : null,
                          ),
                          child: Text(
                            cat,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 36),

                  // Save Button
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Task Saved!")),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF74E0DA),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        "SAVE",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
