import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddTaskScreen extends StatefulWidget {
  final DateTime? selectedDate; // ✅ made optional

  const AddTaskScreen({Key? key, this.selectedDate}) : super(key: key);

  @override
  _AddTaskScreenState createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now(); // ✅ Default date
  }

  Future<void> _selectDate() async {
  final DateTime initialDate = _selectedDate ?? DateTime.now();

  // Keep initial date within allowed range (2025–2027)
  final DateTime safeInitialDate = initialDate.year < 2025
      ? DateTime(2025)
      : (initialDate.year > 2027 ? DateTime(2027) : initialDate);

  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: safeInitialDate,
    firstDate: DateTime(2025, 1, 1),
    lastDate: DateTime(2027, 12, 31),
    selectableDayPredicate: (DateTime day) {
      // Only allow 2025–2027 dates
      return day.year >= 2025 && day.year <= 2027;
    },
  );

  if (picked != null) setState(() => _selectedDate = picked);
}
  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _saveTask() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task saved successfully!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EF),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top pink header
            Container(
              width: double.infinity,
              height: 320,
              decoration: const BoxDecoration(
                color: Color(0xFFFFA8A8),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(50),
                  bottomRight: Radius.circular(50),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "TASK",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 25),
                  // Title input
                  _buildInputField(
                    label: "TITLE",
                    controller: _titleController,
                    icon: Icons.edit,
                  ),
                  const SizedBox(height: 20),
                  // Date picker
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateField(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 35),

            // Start and End Time
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTimeField(
                      label: "START TIME",
                      time: _startTime,
                      onTap: () => _selectTime(true),
                    ),
                  ),
                  const SizedBox(width: 30),
                  Expanded(
                    child: _buildTimeField(
                      label: "END TIME",
                      time: _endTime,
                      onTap: () => _selectTime(false),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 35),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: _buildInputField(
                label: "DESCRIPTION",
                controller: _descriptionController,
                icon: Icons.edit,
              ),
            ),

            const SizedBox(height: 35),

            // Category
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "CATEGORY",
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildCategoryChip(
                          "MEDICATION",
                          const Color(0xFFFFD6D6),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCategoryChip(
                          "EXERCISE",
                          const Color(0xFFFFE28C),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCategoryChip(
                          "OTHER",
                          const Color(0xFFB6EAFF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Save Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ElevatedButton(
                onPressed: _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9BE8D8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  minimumSize: const Size(double.infinity, 45),
                ),
                child: const Text(
                  "SAVE",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40), // Adjusted spacing after removing navbar
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.only(bottom: 5),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black87),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black87),
                  ),
                ),
              ),
            ),
            Icon(icon, color: Colors.black54, size: 18),
          ],
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _selectDate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "DATE",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.arrow_drop_down, size: 20, color: Colors.black54),
              Expanded(
                child: Text(
                  _selectedDate != null
                      ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                      : '',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const Icon(Icons.calendar_today, color: Color(0xFFB6EAFF), size: 25),
            ],
          ),
          const Divider(color: Colors.black87, thickness: 1),
        ],
      ),
    );
  }

  Widget _buildTimeField({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                time != null ? time.format(context) : '',
                style: const TextStyle(fontSize: 14),
              ),
              const Icon(Icons.arrow_drop_down, size: 20, color: Colors.black54),
            ],
          ),
          const Divider(color: Colors.black87, thickness: 1),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, Color color) {
    final bool isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = label),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? Colors.black87 : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
