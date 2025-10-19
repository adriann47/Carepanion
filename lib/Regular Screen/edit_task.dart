import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:softeng/services/rl_service.dart';
import 'package:softeng/services/task_service.dart';

class EditTaskScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final String? forUserId;
  const EditTaskScreen({super.key, required this.task, this.forUserId});

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
  String? _assistedUserId;
  String? _guardianUserId;
  List<ScheduleSuggestion> _suggestions = [];
  bool _loadingSuggestions = false;
  String? _selectedSuggestionId;
  int _suggestionRequestId = 0;
  Timer? _titleDebounce;
  bool _categoryManuallyChosen = false;
  ScheduleRecommendation? _scheduleRecommendation;
  bool _loadingScheduleRecommendation = false;
  List<Map<String, dynamic>> _tasksForDay = [];
  bool _fetchingTasksForDay = false;

  // Title suggestions state
  List<TitleSuggestion> _titleSuggestions = [];
  bool _isLoadingTitleSuggestions = false;
  String _lastTitleSuggestionQuery = '';

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

    _startTime = parseTod(t['start_at']);
    _endTime = parseTod(t['end_at']);

    if (widget.forUserId != null && widget.forUserId!.isNotEmpty) {
      _assistedUserId = widget.forUserId;
    } else {
      final rawUserId = t['user_id']?.toString();
      if (rawUserId != null && rawUserId.isNotEmpty) {
        _assistedUserId = rawUserId;
      } else {
        _assistedUserId = Supabase.instance.client.auth.currentUser?.id;
      }
    }
    _titleController.addListener(_onTitleChanged);
    _loadSuggestions();
    _loadScheduleRecommendation();
    _loadTasksForDay();
  }

  @override
  void dispose() {
    _titleDebounce?.cancel();
    _titleController.removeListener(_onTitleChanged);
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

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedSuggestionId = null;
      });
      _loadSuggestions();
      _loadScheduleRecommendation();
      _loadTasksForDay();
    }
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
        _selectedSuggestionId = null;
      });
    }
  }

  Future<void> _loadSuggestions() async {
    final date = _selectedDate;
    if (date == null) return;
    final requestId = ++_suggestionRequestId;
    setState(() => _loadingSuggestions = true);
    List<ScheduleSuggestion> suggestions = [];
    String? guardianId = _guardianUserId;

    try {
      guardianId ??= await ReinforcementLearningService.resolveGuardianIdFor(
        _assistedUserId,
      );
      suggestions = await ReinforcementLearningService.fetchScheduleSuggestions(
        dueDate: date,
        assistedUserId: _assistedUserId,
        category: _selectedCategory.isEmpty ? null : _selectedCategory,
        guardianId: guardianId,
        taskId: widget.task['id']?.toString(),
        existingTasks: _tasksForDay,
      );
    } catch (_) {
      suggestions = [];
    }

    if (!mounted || requestId != _suggestionRequestId) return;
    setState(() {
      _guardianUserId = guardianId;
      _suggestions = suggestions;
      _loadingSuggestions = false;
    });
  }

  void _applySuggestion(ScheduleSuggestion suggestion) {
    if (_selectedDate == null) return;
    setState(() {
      _startTime = suggestion.start;
      _endTime = suggestion.end;
      _selectedSuggestionId = suggestion.id;
    });
    unawaited(
      ReinforcementLearningService.recordScheduleSelection(
        dueDate: _selectedDate!,
        start: suggestion.start,
        end: suggestion.end,
        assistedUserId: _assistedUserId,
        guardianId: _guardianUserId,
        category: _selectedCategory.isEmpty ? null : _selectedCategory,
        suggestionId: suggestion.id,
        acceptedSuggestion: true,
        duringEdit: true,
        taskId: widget.task['id']?.toString(),
      ),
    );
  }

  Widget _buildSuggestionPanel() {
    if (_selectedDate == null) return const SizedBox.shrink();
    if (_loadingSuggestions) {
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
              'Fetching smart suggestions...',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
        ],
      );
    }

    final chips = _suggestions.map((suggestion) {
      final selected = _selectedSuggestionId == suggestion.id;
      final displayLabel = suggestion.label.isNotEmpty
          ? suggestion.label
          : _formatSuggestionRange(suggestion);
      final hasConflict = _conflictMessageForSuggestion(suggestion) != null;
      return ChoiceChip(
        label: Text(hasConflict ? '(!)' : displayLabel),
        selected: selected,
        selectedColor: hasConflict
            ? const Color(0xFFFFD1D1)
            : const Color(0xFF9BE8D8),
        backgroundColor: hasConflict ? const Color(0xFFFFF1F1) : null,
        onSelected: (value) {
          if (value) {
            _applySuggestion(suggestion);
          } else {
            setState(() => _selectedSuggestionId = null);
          }
        },
      );
    }).toList();

    final selectedSuggestion =
        _selectedSuggestionId != null && _suggestions.isNotEmpty
        ? _suggestions.firstWhere(
            (s) => s.id == _selectedSuggestionId,
            orElse: () => _suggestions.first,
          )
        : null;
    final conflictMessage = selectedSuggestion != null
        ? _conflictMessageForSuggestion(selectedSuggestion)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SMART SUGGESTIONS',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (chips.isNotEmpty) Wrap(spacing: 10, runSpacing: 8, children: chips),
        if (_selectedSuggestionId != null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Suggestion applied. Adjust the fields to override.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        if (conflictMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
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
                    conflictMessage,
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
      ],
    );
  }

  String _formatSuggestionRange(ScheduleSuggestion suggestion) {
    final start = suggestion.start.format(context);
    final end = suggestion.end;
    if (end == null) return start;
    return '$start - ${end.format(context)}';
  }

  Future<void> _loadScheduleRecommendation() async {
    if (_loadingScheduleRecommendation) return;
    setState(() => _loadingScheduleRecommendation = true);
    try {
      final rec =
          await ReinforcementLearningService.fetchScheduleRecommendation(
            assistedUserId: _assistedUserId,
            category: _selectedCategory.isEmpty ? null : _selectedCategory,
          );
      if (!mounted) return;
      setState(() => _scheduleRecommendation = rec);
    } catch (_) {
      if (!mounted) return;
      setState(() => _scheduleRecommendation = null);
    } finally {
      if (mounted) {
        setState(() => _loadingScheduleRecommendation = false);
      }
    }
  }

  Future<void> _loadTasksForDay() async {
    final date = _selectedDate;
    if (date == null) return;
    if (_fetchingTasksForDay) return;
    setState(() => _fetchingTasksForDay = true);
    try {
      final rows = await TaskService.getTasksForDate(
        date,
        forUserId: _assistedUserId,
      );
      if (!mounted) return;
      setState(() => _tasksForDay = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _tasksForDay = []);
    } finally {
      if (mounted) {
        setState(() => _fetchingTasksForDay = false);
      }
    }
  }

  void _onTitleChanged() {
    final text = _titleController.text;
    if (text.isEmpty) {
      setState(() {
        _titleSuggestions = [];
        _lastTitleSuggestionQuery = '';
      });
      return;
    }

    // Debounce suggestions - only fetch if query changed significantly
    if (text.length >= 2 && text != _lastTitleSuggestionQuery) {
      _fetchTitleSuggestions(text);
    }

    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 250), () {
      _classifyTitle(text);
    });
  }

  Future<void> _fetchTitleSuggestions(String query) async {
    setState(() {
      _isLoadingTitleSuggestions = true;
      _lastTitleSuggestionQuery = query;
    });

    try {
      final suggestions =
          await ReinforcementLearningService.fetchTitleSuggestions(
            assistedUserId: _assistedUserId,
            dueDate: _selectedDate,
            startTime: _startTime,
            partialQuery: query,
            category: _selectedCategory.isEmpty ? null : _selectedCategory,
          );

      if (mounted) {
        setState(() {
          _titleSuggestions = suggestions;
          _isLoadingTitleSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _titleSuggestions = [];
          _isLoadingTitleSuggestions = false;
        });
      }
    }
  }

  void _selectTitleSuggestion(TitleSuggestion suggestion) {
    setState(() {
      _titleController.text = suggestion.title;
      _titleSuggestions = []; // Clear suggestions after selection

      // Auto-select category if suggestion has category metadata
      if (suggestion.metadata?['category'] != null) {
        _selectedCategory = suggestion.metadata!['category'] as String;
        _categoryManuallyChosen = false; // Allow auto-classification to work
      }

      // Auto-suggest date and time if available in metadata
      if (suggestion.metadata?['suggested_date_offset'] != null) {
        final offset = suggestion.metadata!['suggested_date_offset'] as int;
        _selectedDate = DateTime.now().add(Duration(days: offset));
        _loadSuggestions(); // Reload time suggestions for new date
        _loadTasksForDay();
      }

      if (suggestion.metadata?['suggested_time'] != null) {
        final timeStr = suggestion.metadata!['suggested_time'] as String;
        final parts = timeStr.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour != null && minute != null) {
            _startTime = TimeOfDay(hour: hour, minute: minute);
            _selectedSuggestionId = null; // Clear time suggestion selection
          }
        }
      }
    });
  }

  int _classifyRequestId = 0;
  Future<void> _classifyTitle(String title) async {
    if (title.trim().length < 3) return;
    final requestId = ++_classifyRequestId;
    final result = await ReinforcementLearningService.classifyTitle(title);
    if (!mounted || requestId != _classifyRequestId) return;
    if (result == null) return;
    final mapped = _mapCategoryToChip(result);
    if (mapped == null) return;
    if (_categoryManuallyChosen) return;
    if (_selectedCategory == mapped) return;

    setState(() => _selectedCategory = mapped);
    _loadSuggestions();
    _loadScheduleRecommendation();
  }

  String? _mapCategoryToChip(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('health') || lower.contains('medicine')) {
      return 'MEDICATION';
    }
    if (lower.contains('fitness') || lower.contains('exercise')) {
      return 'EXERCISE';
    }
    if (lower.contains('finance') ||
        lower.contains('money') ||
        lower.contains('bill') ||
        lower.contains('communication') ||
        lower.contains('call')) {
      return 'OTHER';
    }
    return null;
  }

  String? _conflictMessageForSuggestion(ScheduleSuggestion suggestion) {
    final date = _selectedDate;
    if (date == null) return null;
    return _conflictMessageForRange(suggestion.start, suggestion.end, date);
  }

  String? _activeTimeConflict() {
    final date = _selectedDate;
    if (date == null || _startTime == null) return null;
    return _conflictMessageForRange(_startTime!, _endTime, date);
  }

  String? _conflictMessageForRange(
    TimeOfDay start,
    TimeOfDay? end,
    DateTime date,
  ) {
    if (_tasksForDay.isEmpty) return null;
    final startDate = _buildDateTime(date, start);
    final endDate = _buildDateTime(
      date,
      end ?? start,
    ).add(end == null ? const Duration(minutes: 5) : Duration.zero);
    for (final task in _tasksForDay) {
      // Skip the current task being edited
      final taskId = task['id']?.toString();
      final currentTaskId = widget.task['id']?.toString();
      if (taskId != null && currentTaskId != null && taskId == currentTaskId)
        continue;

      final otherStart = _parseTaskTime(task['start_at'], date);
      if (otherStart == null) continue;
      final otherEnd =
          _parseTaskTime(task['end_at'], date) ??
          otherStart.add(const Duration(minutes: 15));
      if (_rangesOverlap(startDate, endDate, otherStart, otherEnd)) {
        final title = (task['title'] ?? 'another reminder').toString();
        final conflictAt = TimeOfDay.fromDateTime(otherStart).format(context);
        final tryAt = TimeOfDay.fromDateTime(
          startDate.subtract(const Duration(minutes: 5)),
        ).format(context);
        return 'Clashes with "$title" at $conflictAt - try $tryAt?';
      }
    }
    return null;
  }

  DateTime _buildDateTime(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  DateTime? _parseTaskTime(dynamic raw, DateTime date) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString()).toLocal();
    } catch (_) {
      final time = _parseTimeOfDay(raw.toString());
      if (time == null) return null;
      return _buildDateTime(date, time);
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

  bool _rangesOverlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  Future<void> _saveTask() async {
    final id = (widget.task['id'] as num).toInt();

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a date')));
      return;
    }

    try {
      final assistedId =
          _assistedUserId ??
          widget.forUserId ??
          widget.task['user_id']?.toString() ??
          Supabase.instance.client.auth.currentUser?.id;
      _assistedUserId = assistedId;
      final guardianFuture = assistedId != null
          ? ReinforcementLearningService.resolveGuardianIdFor(assistedId)
          : Future<String?>.value(null);

      await TaskService.updateTask(
        id: id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _selectedDate,
        startTime: _startTime,
        endTime: _endTime,
        category: _selectedCategory.isEmpty ? null : _selectedCategory,
        forUserId: widget.forUserId ?? widget.task['user_id'] as String?,
      );

      final guardianId = await guardianFuture;
      unawaited(
        ReinforcementLearningService.recordScheduleSelection(
          dueDate: _selectedDate!,
          start: _startTime,
          end: _endTime,
          assistedUserId: assistedId,
          guardianId: guardianId,
          category: _selectedCategory.isEmpty ? null : _selectedCategory,
          suggestionId: _selectedSuggestionId,
          acceptedSuggestion: _selectedSuggestionId != null,
          duringEdit: true,
          taskId: id.toString(),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task updated successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save task: $e')));
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final ok = await TaskService.deleteTask(
        id,
        forUserId: widget.forUserId ?? widget.task['user_id'] as String?,
      );
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Task deleted')));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Task not deleted. It may not exist or you may not have permission.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EF),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
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
                  // Title input with suggestions
                  _buildTitleInputWithSuggestions(),
                  const SizedBox(height: 20),
                  Row(children: [Expanded(child: _buildDateField())]),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: _buildSuggestionPanel(),
            ),
            if (_loadingScheduleRecommendation)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_scheduleRecommendation != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Suggested schedule: ${_scheduleRecommendation!.daysLabel} at ${_scheduleRecommendation!.timeLabel}',
                    style: const TextStyle(
                      color: Color(0xFF3A4A5A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
            if (_activeTimeConflict() != null)
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
                        _activeTimeConflict()!,
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
              const Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: Colors.black54,
              ),
              Expanded(
                child: Text(
                  _selectedDate != null
                      ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                      : '',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const Icon(
                Icons.calendar_today,
                color: Color(0xFFB6EAFF),
                size: 25,
              ),
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
              const Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: Colors.black54,
              ),
            ],
          ),
          const Divider(color: Colors.black87, thickness: 1),
        ],
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

        // Title suggestions list
        if (_isLoadingTitleSuggestions)
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
                  onTap: () => _selectTitleSuggestion(suggestion),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: index < _titleSuggestions.length - 1
                          ? Border(
                              bottom: BorderSide(color: Colors.grey.shade200),
                            )
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(
                                suggestion.metadata!['category'] as String,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              (suggestion.metadata!['category'] as String)
                                  .substring(0, 3),
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

  Widget _buildCategoryChip(String label, Color color) {
    final bool isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () {
        if (_selectedCategory == label) return;
        setState(() {
          _selectedCategory = label;
          _selectedSuggestionId = null;
        });
        _loadSuggestions();
        _loadScheduleRecommendation();
        _loadTasksForDay();
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
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }
}
