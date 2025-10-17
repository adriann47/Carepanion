import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:softeng/services/task_service.dart';
import 'package:softeng/services/rl_service.dart';

class AddTaskScreen extends StatefulWidget {
  final DateTime? selectedDate; // Made optional
  final String? forUserId; // optional target user id (guardian creating for assisted)

  const AddTaskScreen({super.key, this.selectedDate, this.forUserId});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _selectedCategory = '';

  // Title suggestions state
  List<TitleSuggestion> _titleSuggestions = [];
  bool _isLoadingSuggestions = false;
  String _lastSuggestionQuery = '';

  // Time suggestions state
  List<ScheduleSuggestion> _timeSuggestions = [];
  bool _isLoadingTimeSuggestions = false;
  String? _selectedTimeSuggestionId;
  int _timeSuggestionRequestId = 0;
  List<Map<String, dynamic>> _existingTasksForDay = [];
  bool _fetchingTasksForDay = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now(); // Default date

    // Add listener to title controller for suggestions
    _titleController.addListener(_onTitleChanged);
    _loadTimeSuggestions();
    _loadExistingTasksForDay();
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    super.dispose();
  }

  void _onTitleChanged() {
    final query = _titleController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _titleSuggestions = [];
        _lastSuggestionQuery = '';
      });
      return;
    }

    // Debounce suggestions - only fetch if query changed significantly
    if (query.length >= 2 && query != _lastSuggestionQuery) {
      _fetchTitleSuggestions(query);
    }
  }

  Future<void> _fetchTitleSuggestions(String query) async {
    setState(() {
      _isLoadingSuggestions = true;
      _lastSuggestionQuery = query;
    });

    try {
      final suggestions = await ReinforcementLearningService.fetchTitleSuggestions(
        assistedUserId: widget.forUserId,
        dueDate: _selectedDate,
        startTime: _startTime,
        partialQuery: query,
        category: _selectedCategory.isEmpty ? null : _selectedCategory,
      );

      if (mounted) {
        setState(() {
          _titleSuggestions = suggestions;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _titleSuggestions = [];
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  void _selectSuggestion(TitleSuggestion suggestion) {
    setState(() {
      _titleController.text = suggestion.title;
      _titleSuggestions = []; // Clear suggestions after selection

      // Auto-select category if suggestion has category metadata
      if (suggestion.metadata?['category'] != null) {
        _selectedCategory = suggestion.metadata!['category'] as String;
      }

      // Auto-suggest date and time if available in metadata
      if (suggestion.metadata?['suggested_date_offset'] != null) {
        final offset = suggestion.metadata!['suggested_date_offset'] as int;
        _selectedDate = DateTime.now().add(Duration(days: offset));
        _loadTimeSuggestions();
        _loadExistingTasksForDay();
      }

      if (suggestion.metadata?['suggested_time'] != null) {
        final timeStr = suggestion.metadata!['suggested_time'] as String;
        final parts = timeStr.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour != null && minute != null) {
            _startTime = TimeOfDay(hour: hour, minute: minute);
            _selectedTimeSuggestionId = null;
          }
        }
      }
    });
  }

  Future<void> _loadTimeSuggestions() async {
    final date = _selectedDate;
    if (date == null) return;
    final requestId = ++_timeSuggestionRequestId;
    setState(() => _isLoadingTimeSuggestions = true);

    try {
      final suggestions = await ReinforcementLearningService.fetchScheduleSuggestions(
        dueDate: date,
        assistedUserId: widget.forUserId,
        category: _selectedCategory.isEmpty ? null : _selectedCategory,
        existingTasks: _existingTasksForDay,
      );

      if (mounted && requestId == _timeSuggestionRequestId) {
        setState(() {
          _timeSuggestions = suggestions;
          _isLoadingTimeSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted && requestId == _timeSuggestionRequestId) {
        setState(() {
          _timeSuggestions = [];
          _isLoadingTimeSuggestions = false;
        });
      }
    }
  }

  Future<void> _loadExistingTasksForDay() async {
    final date = _selectedDate;
    if (date == null) return;
    if (_fetchingTasksForDay) return;
    setState(() => _fetchingTasksForDay = true);

    try {
      final rows = await TaskService.getTasksForDate(date, forUserId: widget.forUserId);
      if (mounted) {
        setState(() => _existingTasksForDay = rows);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _existingTasksForDay = []);
      }
    } finally {
      if (mounted) {
        setState(() => _fetchingTasksForDay = false);
      }
    }
  }

  void _applyTimeSuggestion(ScheduleSuggestion suggestion) {
    if (_selectedDate == null) return;
    setState(() {
      _startTime = suggestion.start;
      _endTime = suggestion.end;
      _selectedTimeSuggestionId = suggestion.id;
    });
  }

  String _formatTimeSuggestionLabel(ScheduleSuggestion suggestion) {
    final start = suggestion.start.format(context);
    final end = suggestion.end;
    if (end == null) return start;
    return '$start - ${end.format(context)}';
  }

  String? _timeConflictMessage() {
    final date = _selectedDate;
    if (date == null || _startTime == null) return null;
    return _conflictMessageForRange(_startTime!, _endTime, date);
  }

  String? _conflictMessageForRange(TimeOfDay start, TimeOfDay? end, DateTime date) {
    if (_existingTasksForDay.isEmpty) return null;
    final startDate = DateTime(date.year, date.month, date.day, start.hour, start.minute);
    final endDate = end != null
        ? DateTime(date.year, date.month, date.day, end.hour, end.minute)
        : startDate.add(const Duration(minutes: 15));

    for (final task in _existingTasksForDay) {
      final otherStart = _parseTaskTime(task['start_at'], date);
      if (otherStart == null) continue;
      final otherEnd = _parseTaskTime(task['end_at'], date) ?? otherStart.add(const Duration(minutes: 15));

      if (startDate.isBefore(otherEnd) && otherStart.isBefore(endDate)) {
        final title = (task['title'] ?? 'another task').toString();
        return 'Conflicts with "$title"';
      }
    }
    return null;
  }

  DateTime? _parseTaskTime(dynamic raw, DateTime date) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString()).toLocal();
    } catch (_) {
      final time = _parseTimeOfDay(raw.toString());
      if (time == null) return null;
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }
  }

  TimeOfDay? _parseTimeOfDay(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _selectDate() async {
    final DateTime initialDate = _selectedDate ?? DateTime.now();

    // Keep initial date within allowed range (2025-2027)
    final DateTime safeInitialDate = initialDate.year < 2025
        ? DateTime(2025)
        : (initialDate.year > 2027 ? DateTime(2027) : initialDate);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: safeInitialDate,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2027, 12, 31),
      selectableDayPredicate: (DateTime day) {
        // Only allow 2025-2027 dates
        return day.year >= 2025 && day.year <= 2027;
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadTimeSuggestions();
      _loadExistingTasksForDay();
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final now = DateTime.now();
      final pickedDt = DateTime(
        _selectedDate?.year ?? now.year,
        _selectedDate?.month ?? now.month,
        _selectedDate?.day ?? now.day,
        picked.hour,
        picked.minute,
      );

      if (isStart) {
        // If selecting a start time for today, disallow times before now
        if (_selectedDate != null && pickedDt.isBefore(now)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot set a start time in the past')),
          );
          return;
        }
      } else {
        // End time rules: cannot be in the past, and if start exists, must be after start
        if (pickedDt.isBefore(now)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot set an end time in the past')),
          );
          return;
        }
        if (_startTime != null && _selectedDate != null) {
          final startDt = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _startTime!.hour,
            _startTime!.minute,
          );
          if (!pickedDt.isAfter(startDt)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('End time must be after start time')),
            );
            return;
          }
        }
      }

      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
        _selectedTimeSuggestionId = null; // Clear time suggestion selection
      });
    }
  }

  Future<void> _saveTask() async {
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
      // Additional validation: startTime should not be in the past for the selected date
      if (_startTime != null && _selectedDate != null) {
        final now = DateTime.now();
        final startDt = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _startTime!.hour,
          _startTime!.minute,
        );
        if (startDt.isBefore(now)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Start time cannot be in the past')),
            );
          }
          return;
        }
      }

      // Additional validation: end time must be after start and not in the past
      if (_endTime != null && _selectedDate != null) {
        final now = DateTime.now();
        final endDt = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _endTime!.hour,
          _endTime!.minute,
        );
        if (endDt.isBefore(now)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('End time cannot be in the past')),
            );
          }
          return;
        }
        if (_startTime != null) {
          final startDt = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _startTime!.hour,
            _startTime!.minute,
          );
          if (!endDt.isAfter(startDt)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('End time must be after start time')),
              );
            }
            return;
          }
        }
      }

      await TaskService.createTask(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        dueDate: _selectedDate!,
        startTime: _startTime,
        endTime: _endTime,
        category: _selectedCategory.isEmpty ? null : _selectedCategory,
        forUserId: widget.forUserId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task saved successfully!')),
        );
        Navigator.pop(context, true); // return success
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save task: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EF),
      resizeToAvoidBottomInset: true, // <-- Fix overflow when keyboard appears
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min, // <-- Prevent overflow
            children: [
              // Top pink header
              Container(
                width: double.infinity,
                // height removed to avoid overflow when keyboard shows
                // height: 320,
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
                    // Title input with suggestions
                    _buildTitleInputWithSuggestions(),
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

              // Time suggestions
              if (_selectedDate != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: _buildTimeSuggestionsPanel(),
                ),

              if (_timeConflictMessage() != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 6, 30, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFB53030),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _timeConflictMessage()!,
                          style: const TextStyle(
                            color: Color(0xFFB53030),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
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
      ),
    );
  }

  Widget _buildTitleInputWithSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title input field
        _buildInputField(
          label: "TITLE",
          controller: _titleController,
          icon: Icons.edit,
        ),

        // Suggestions list
        if (_isLoadingSuggestions)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_titleSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _titleSuggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _titleSuggestions[index];
                return InkWell(
                  onTap: () => _selectSuggestion(suggestion),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: index < _titleSuggestions.length - 1
                          ? Border(bottom: BorderSide(color: Colors.grey.shade200))
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Emoji if available
                        if (suggestion.emoji != null) ...[
                          Text(
                            suggestion.emoji!,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 12),
                        ],

                        // Title and reason
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                suggestion.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                suggestion.reason,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Category indicator if available
                        if (suggestion.metadata?['category'] != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(suggestion.metadata!['category'] as String),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              (suggestion.metadata!['category'] as String).substring(0, 3),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'MEDICATION':
        return const Color(0xFFFFD6D6);
      case 'EXERCISE':
        return const Color(0xFFFFE28C);
      default:
        return const Color(0xFFB6EAFF);
    }
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
      onTap: () {
        setState(() => _selectedCategory = label);
        _loadTimeSuggestions();
      },
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

  Widget _buildTimeSuggestionsPanel() {
    if (_isLoadingTimeSuggestions) {
      return Row(
        children: const [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Loading smart time suggestions...',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
        ],
      );
    }

    if (_timeSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final chips = _timeSuggestions.map((suggestion) {
      final selected = _selectedTimeSuggestionId == suggestion.id;
      final displayLabel = suggestion.label.isNotEmpty
          ? suggestion.label
          : _formatTimeSuggestionLabel(suggestion);
      final hasConflict = _conflictMessageForRange(suggestion.start, suggestion.end, _selectedDate!) != null;

      return ChoiceChip(
        label: Text(hasConflict ? '(!)' : displayLabel),
        selected: selected,
        selectedColor: hasConflict ? const Color(0xFFFFD1D1) : const Color(0xFF9BE8D8),
        backgroundColor: hasConflict ? const Color(0xFFFFF1F1) : null,
        onSelected: (value) {
          if (value) {
            _applyTimeSuggestion(suggestion);
          } else {
            setState(() => _selectedTimeSuggestionId = null);
          }
        },
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SMART TIME SUGGESTIONS',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: chips,
        ),
        if (_selectedTimeSuggestionId != null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Suggestion applied. Adjust the time fields to override.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}