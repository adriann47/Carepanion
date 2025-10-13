import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:softeng/services/task_service.dart';

class EditTaskScreen extends StatefulWidget {
final Map<String, dynamic> task;
const EditTaskScreen({super.key, required this.task});

@override
State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
final TextEditingController _titleController = TextEditingController();
final TextEditingController _descriptionController = TextEditingController();
DateTime? _selectedDate;
TimeOfDay? _startTime;
TimeOfDay? _endTime;
String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    final t = widget.task;

    _titleController.text = (t['title'] ?? '').toString();
    _descriptionController.text = (t['description'] ?? '').toString();

    final due = t['due_date']?.toString();
    if (due != null && due.isNotEmpty) {
      try {
        _selectedDate = DateTime.parse(due);
      } catch (_) {}
    }

    final cat = t['category']?.toString();
    if (cat != null && cat.isNotEmpty) _selectedCategory = cat;

    TimeOfDay? parseTod(dynamic iso) {
      if (iso == null) return null;
      try {
        final dt = DateTime.parse(iso.toString()).toLocal();
        return TimeOfDay(hour: dt.hour, minute: dt.minute);
      } catch (_) {
        return null;
      }
    }
@override
void initState() {
super.initState();
final t = widget.task;
_titleController.text = (t['title'] ?? '').toString();
_descriptionController.text = (t['description'] ?? '').toString();

final due = t['due_date']?.toString();
if (due != null && due.isNotEmpty) {
try { _selectedDate = DateTime.parse(due); } catch (_) {}
}
final cat = t['category']?.toString();
if (cat != null && cat.isNotEmpty) _selectedCategory = cat;

TimeOfDay? parseTod(dynamic iso) {
if (iso == null) return null;
try {
final dt = DateTime.parse(iso.toString()).toLocal();
return TimeOfDay(hour: dt.hour, minute: dt.minute);
} catch (_) { return null; }
}
_startTime = parseTod(t['start_at']);
_endTime = parseTod(t['end_at']);
}

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime initialDate = _selectedDate ?? DateTime.now();

    // Keep initial date within allowed range (2025–2027) to mirror Add Task
    final DateTime safeInitialDate = initialDate.year < 2025
        ? DateTime(2025)
        : (initialDate.year > 2027 ? DateTime(2027) : initialDate);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: safeInitialDate,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2027, 12, 31),
      selectableDayPredicate: (DateTime day) =>
          day.year >= 2025 && day.year <= 2027,
    );
Future<void> _selectDate() async {
final DateTime initialDate = _selectedDate ?? DateTime.now();

// Keep initial date within allowed range (2025–2027) like Add Task
final DateTime safeInitialDate = initialDate.year < 2025
? DateTime(2025)
: (initialDate.year > 2027 ? DateTime(2027) : initialDate);

final DateTime? picked = await showDatePicker(
context: context,
initialDate: safeInitialDate,
firstDate: DateTime(2025, 1, 1),
lastDate: DateTime(2027, 12, 31),
selectableDayPredicate: (DateTime day) {
return day.year >= 2025 && day.year <= 2027;
},
);

if (picked != null) setState(() => _selectedDate = picked);
}

  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now(),
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

  Future<void> _saveTask() async {
    final id = (widget.task['id'] as num).toInt();

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
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

Future<void> _saveTask() async {
final id = (widget.task['id'] as num).toInt();
if ((_titleController.text).trim().isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Please enter a title')),
);
return;
}
if (_selectedDate == null) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Please select a date')),
);
return;
}

try {
await TaskService.updateTask(
id: id,
title: _titleController.text.trim(),
description: _descriptionController.text.trim(),
dueDate: _selectedDate,
startTime: _startTime,
endTime: _endTime,
category: _selectedCategory.isEmpty ? null : _selectedCategory,
);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task updated successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save task: $e')),
      );
    }
  }

  Future<void> _deleteTask() async {
    final id = (widget.task['id'] as num).toInt();

    // Optional confirm dialog (remove if you don’t want it)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final ok = await TaskService.deleteTask(id);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task deleted')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task not deleted. It may not exist or you may not have permission.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EF),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.black87),
                        onPressed: _deleteTask,
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "EDIT TASK",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 25),
                  _buildInputField(
                    label: "TITLE",
                    controller: _titleController,
                    icon: Icons.edit,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildDateField()),
                    ],
                  ),
                ],
              ),
            ),
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Task updated successfully!')),
);
Navigator.pop(context, true);
}
} catch (e) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Failed to save task: $e')),
);
}
}

Future<void> _deleteTask() async {
final id = (widget.task['id'] as num).toInt();
try {
  await TaskService.deleteTask(id);
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Task deleted')),
  );
  Navigator.pop(context, true);
} catch (e) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Failed to delete: $e')),
);
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFFFAF6EF),
body: SingleChildScrollView(
child: Column(
children: [
// Top pink header (copied from Add Task)
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
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
IconButton(
icon: const Icon(Icons.arrow_back, color: Colors.black),
onPressed: () => Navigator.pop(context),
),
IconButton(
icon: const Icon(Icons.delete, color: Colors.black87),
onPressed: _deleteTask,
tooltip: 'Delete',
),
],
),
const SizedBox(height: 10),
const Text(
"EDIT TASK",
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

            // Start / End Time
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

            // Save button
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

const SizedBox(height: 40),
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
