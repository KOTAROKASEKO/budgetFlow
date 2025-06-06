import 'package:flutter/material.dart';
import 'package:moneymanager/aisupport/AIRoadMap_DashBoard/View_AIRoadMap.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:moneymanager/aisupport/AIRoadMap_DashBoard/notes/note_veiwmodel.dart';
import 'package:table_calendar/table_calendar.dart';

class AIFinanceViewModel extends ChangeNotifier {
  final AIFinanceRepository _repository;
  final NoteViewModel noteViewModel;

  AIFinanceViewModel({required this.noteViewModel, required AIFinanceRepository repository})
      : _repository = repository {
    loadInitialData();
  }

  TaskHiveModel? _currentActiveGoal;
  TaskHiveModel? get currentActiveGoal => _currentActiveGoal;

  List<TaskHiveModel> _draggableDailyTasks = [];
  List<TaskHiveModel> get draggableDailyTasks => _draggableDailyTasks;

  Map<DateTime, List<TaskHiveModel>> _calendarTasks = {};
  Map<DateTime, List<TaskHiveModel>> get calendarTasks => _calendarTasks;

  DateTime _focusedDay = DateTime.now();
  DateTime get focusedDay => _focusedDay;

  DateTime? _selectedDay = DateTime.now();
  DateTime? get selectedDay => _selectedDay;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  CalendarFormat get calendarFormat => _calendarFormat;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> loadInitialData() async {
    _setLoading(true);
    final goals = await _repository.syncAndGetGoalTasks();
    if (goals.isNotEmpty) {
      _currentActiveGoal = goals.first;
      await _loadTasksForGoal(_currentActiveGoal!.id);
      if (_selectedDay != null) {
        noteViewModel.loadNoteForDay(_selectedDay!, _currentActiveGoal!.id);
      }
    }
    _setLoading(false);
  }

  Future<void> _loadTasksForGoal(String goalId) async {
    final allSubTasks = await _fetchAllSubTasksRecursive(goalId);
    final dailyTasks = allSubTasks.where((task) => task.taskLevel == TaskLevelName.Daily).toList();

    final newCalendarTasks = <DateTime, List<TaskHiveModel>>{};
    final newDraggableTasks = <TaskHiveModel>[];

    for (var task in dailyTasks) {
      if (task.dueDate != null) {
        final dateKey = DateTime.utc(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
        newCalendarTasks.putIfAbsent(dateKey, () => []).add(task);
      }
      if (!task.isDone && task.status != 'scheduled_on_calendar') {
        newDraggableTasks.add(task);
      }
    }
    _calendarTasks = newCalendarTasks;
    _draggableDailyTasks = newDraggableTasks;
    notifyListeners();
  }

  Future<List<TaskHiveModel>> _fetchAllSubTasksRecursive(String parentId) async {
    List<TaskHiveModel> allTasks = [];
    final children = await _repository.getSubTasks(parentId);
    for (var child in children) {
      allTasks.add(child);
      if (child.taskLevel != TaskLevelName.Daily) {
        allTasks.addAll(await _fetchAllSubTasksRecursive(child.id));
      }
    }
    return allTasks;
  }

  void onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      if (_currentActiveGoal != null) {
        noteViewModel.loadNoteForDay(selectedDay, _currentActiveGoal!.id);
      }
      notifyListeners();
    }
  }

  void onFormatChanged(CalendarFormat format) {
    if (_calendarFormat != format) {
      _calendarFormat = format;
      notifyListeners();
    }
  }
  
  void onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    notifyListeners();
  }

  Future<void> handleTaskDroppedOnCalendar(TaskHiveModel task, DateTime date) async {
    task.dueDate = DateTime.utc(date.year, date.month, date.day);
    task.status = 'scheduled_on_calendar';
    await _repository.updateTask(task);
    if (_currentActiveGoal != null) {
      await _loadTasksForGoal(_currentActiveGoal!.id);
    }
  }

  Future<void> toggleTaskCompletion(TaskHiveModel task) async {
    task.isDone = !task.isDone;
    task.status = task.isDone ? "completed" : "pending";
    await _repository.updateTask(task);
    notifyListeners();
  }

  List<TaskHiveModel> getTasksForDay(DateTime day) {
    return _calendarTasks[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }
}