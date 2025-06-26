// lib/aisupport/DashBoard_MapTask/ViewModel_AIRoadMap.dart

import 'package:flutter/material.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/Repository_DashBoard.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/streak/streak_hive_model.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/streak/streak_repository.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/AI_Service.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/notes/note_veiwmodel.dart';
import 'package:moneymanager/notification_service/notification_service.dart';
import 'package:moneymanager/print/print.dart';
import 'package:moneymanager/security/uid.dart';
import 'package:table_calendar/table_calendar.dart';

class AIFinanceViewModel extends ChangeNotifier {
  final AIFinanceRepository _repository;
  final NoteViewModel noteViewModel;
  final StreakRepository _streakRepository;
  AIPlanningService? _aiService;

  AIFinanceViewModel({
    required this.noteViewModel,
    required AIFinanceRepository repository,
    required StreakRepository streakRepository,
  })  : _repository = repository,
        _streakRepository = streakRepository {
    loadInitialData();
  }

  TaskHiveModel? _currentActiveGoal;
  TaskHiveModel? get currentActiveGoal => _currentActiveGoal;

  TaskHiveModel? _activeMilestone;
  TaskHiveModel? get activeMilestone => _activeMilestone;

  List<TaskHiveModel> _availableMilestones = [];
  List<TaskHiveModel> get availableMilestones => _availableMilestones;

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

  String? _loadingMessage;
  String? get loadingMessage => _loadingMessage;

  bool _goalAvailability = false;
  bool get goalAvailability => _goalAvailability;

  StreakHiveModel? _streakData;
  StreakHiveModel? get streakData => _streakData;

  String _streakMessage = '';
  String get streakMessage => _streakMessage;

  bool _showCelebration = false;
  bool get showCelebration => _showCelebration;

  static const Map<int, int> _streakPoints = {
    1: 1, 2: 1, 3: 3, 4: 1, 5: 6, 6: 10, 7: 100
  };

  String _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image12.png?alt=media&token=c9e1f111-0316-4fcc-9917-ef58dfebbc6f';
  String get picUrl => _picUrl;

  Future<void> deleteTask(String taskId) async {
    await _repository.deleteTaskWithChildren(taskId);
    await loadInitialData();
  }

  Future<List<TaskHiveModel>> fetchAllCompletedTasks() async {
    final allTasks = await _repository.getAllTasks();
    final completedTasks = allTasks.where((task) => task.isDone).toList();
    completedTasks.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return b.dueDate!.compareTo(a.dueDate!);
    });
    return completedTasks;
  }

  int get totalDailyTasks {
    int calendarTaskCount = _calendarTasks.values.fold(0, (sum, list) => sum + list.length);
    return _draggableDailyTasks.length + calendarTaskCount;
  }

  int get completedDailyTasks {
    int completedInCalendar = _calendarTasks.values.expand((list) => list).where((task) => task.isDone).length;
    int completedInDraggable = _draggableDailyTasks.where((task) => task.isDone).length;
    return completedInCalendar + completedInDraggable;
  }

  double get dailyTaskCompletionPercentage {
    if (totalDailyTasks == 0) return 0.0;
    return completedDailyTasks / totalDailyTasks;
  }

  void _setLoading(bool loading, {String? message}) {
    _isLoading = loading;
    _loadingMessage = message;
    notifyListeners();
  }

  Future<void> _updateStreakMessage(int streakDay) async {
    final doc = await _streakRepository.getMessage();
    _streakMessage = doc[streakDay.toString()] ?? "Hey welcome!!\nHow's your day going?";
    notifyListeners();
  }

  void setAvatar(int streakDay) {
    _updateStreakMessage(streakDay);
    switch (streakDay) {
      case 0: _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image12.png?alt=media&token=c9e1f111-0316-4fcc-9917-ef58dfebbc6f'; break;
      case 1: _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image0.png?alt=media&token=f2e3b0df-dfc7-4343-b990-7786a21877f5'; break;
      case 2: _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image2.png?alt=media&token=3702a196-97fc-4d53-a12c-621c9a49f560'; break;
      case 3: _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image3.png?alt=media&token=92ac97b2-4022-447c-acff-a9c627d07006'; break;
      case 4: _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image4.png?alt=media&token=36028ffa-f4fa-420f-a196-b95e6a38452c'; break;
      case 5: _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image5.png?alt=media&token=b5b289f8-2824-404f-997a-9095f0149414'; break;
      case 6: _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image6.png?alt=media&token=7e20cf65-0b69-4358-8f90-9b049aa92894'; break;
      case 7: _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image7.png?alt=media&token=395049d4-1795-4801-9cf7-d8b58f5c968c'; break;
      default: _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image0.png?alt=media&token=f2e3b0df-dfc7-4343-b990-7786a21877f5';
    }
    notifyListeners();
  }

  Future<void> loadInitialData() async {
    _setLoading(true, message: "Loading your plan...");
    await _loadAndCheckStreak();
    setAvatar(_streakData?.currentStreak ?? 0);

    final goals = await _repository.syncAndGetGoalTasks();
    if (goals.isNotEmpty) {
      _currentActiveGoal = goals.first;
      _initializeAIService(_currentActiveGoal!);
      await _loadTasksForGoal(_currentActiveGoal!.id);
      if (_selectedDay != null) {
        noteViewModel.loadNoteForDay(_selectedDay!, _currentActiveGoal!.id);
      }
      toggleGoalCreationAvailability(false);
    } else {
      _currentActiveGoal = null;
      _activeMilestone = null;
      _availableMilestones.clear();
      _draggableDailyTasks.clear();
      _calendarTasks.clear();
      noteViewModel.clearCurrentNote();
      toggleGoalCreationAvailability(true);
    }
    _setLoading(false);
  }

  void _initializeAIService(TaskHiveModel goal) {
    _aiService = AIPlanningService(
      earnThisYear: goal.userInputEarnTarget ?? '',
      currentSkill: goal.userInputCurrentSkill ?? '',
      preferToEarnMoney: goal.userInputPreferToEarnMoney ?? '',
      note: goal.userInputNote ?? '',
    );
  }

  Future<String?> startMilestone(TaskHiveModel milestone) async {
    if (_aiService == null) return "AI Service not ready. Please restart.";
    if (milestone.taskLevel != TaskLevelName.Milestone) return "This is not a valid milestone.";

    _setLoading(true, message: "Generating daily tasks...");

    try {
      if (_activeMilestone != null && _activeMilestone!.id != milestone.id) {
        _activeMilestone!.status = 'pending';
        await _repository.updateTask(_activeMilestone!);
      }

      milestone.status = 'active';
      await _repository.updateTask(milestone);
      
      final existingDailyTasks = await _repository.getSubTasks(milestone.id);
      if (existingDailyTasks.isEmpty) {
        final List<TaskHiveModel> dailyTasks = await _aiService!.fetchAIPlan(parentTask: milestone);
        await _repository.saveAllTasks(dailyTasks);
        await _repository.backupPlanToFirestore(dailyTasks);
      }

      await _loadTasksForGoal(_currentActiveGoal!.id);
      _setLoading(false);
      return null;
    } catch (e) {
      _setLoading(false);
      return "Failed to generate daily tasks: ${e.toString()}";
    }
  }

  Future<void> _loadAndCheckStreak() async {
    _streakData = await _streakRepository.getStreak();
    if (_streakData == null) {
      _streakData = StreakHiveModel.initial();
      await _streakRepository.saveStreak(_streakData!);
    }
  }

  Future<void> _loadTasksForGoal(String goalId) async {
    final allSubTasks = await _fetchAllSubTasksRecursive(goalId);
    
    final milestones = allSubTasks.where((task) => task.taskLevel == TaskLevelName.Milestone).toList();
    _activeMilestone = milestones.where((m) => m.status == 'active').isNotEmpty
        ? milestones.firstWhere((m) => m.status == 'active')
        : null;

    _availableMilestones = milestones.where((m) => m.status != 'active' && !m.isDone).toList();
    _availableMilestones.sort((a, b) => a.order.compareTo(b.order));

    final dailyTasks = allSubTasks.where((task) => task.taskLevel == TaskLevelName.Daily).toList();
    final newCalendarTasks = <DateTime, List<TaskHiveModel>>{};
    final newDraggableTasks = <TaskHiveModel>[];

    for (var task in dailyTasks) {
      if (task.dueDate != null) {
        final dateKey = DateTime.utc(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
        newCalendarTasks.putIfAbsent(dateKey, () => []).add(task);
      } else {
        if (_activeMilestone != null && task.parentTaskId == _activeMilestone!.id) {
          newDraggableTasks.add(task);
        }
      }
    }
    _calendarTasks = newCalendarTasks;
    _draggableDailyTasks = newDraggableTasks;
    _draggableDailyTasks.sort((a, b) => a.order.compareTo(b.order));
    
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

  Future<void> returnTaskToDraggableList(TaskHiveModel task) async {
    await NotificationService().cancelTaskReminder(task.id);
    task.dueDate = null;
    task.status = 'pending';
    task.notificationTime = null;
    await _repository.updateTask(task);
    if (_currentActiveGoal != null) {
      await _loadTasksForGoal(_currentActiveGoal!.id);
    }
  }

  Future<void> updateTask(TaskHiveModel hive) async {
    await _repository.updateTask(hive);
  }

  Future<void> _updateStreakAndPoints() async {
    if (_streakData == null) await _loadAndCheckStreak();

    final today = DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final lastDate = _streakData!.lastCompletionDate;

    if (lastDate != null && isSameDay(lastDate, today)) {
      return;
    }

    final yesterday = today.subtract(const Duration(days: 1));

    if (lastDate != null && isSameDay(lastDate, yesterday)) {
      _streakData!.currentStreak++;
      if (_streakData!.currentStreak == 7) {
        _showCelebration = true;
        notifyListeners();
        Future.delayed(const Duration(seconds: 8), () {
          _showCelebration = false;
          notifyListeners();
        });
      }
      D.p('Updated Streak : ${_streakData!.currentStreak}');
    } else {
      _streakData!.currentStreak = 1;
    }

    if (_streakData!.currentStreak > 7) {
      _streakData!.currentStreak = 1;
      D.p('Updated Streak because the streak was over 7: ${_streakData!.currentStreak}');
    }

    final pointsToAdd = _streakPoints[_streakData!.currentStreak] ?? 0;
    _streakData!.totalPoints += pointsToAdd;
    _streakData!.lastCompletionDate = today;

    await _streakRepository.saveStreak(_streakData!);
    _streakRepository.saveStreakToFirestore(userId.uid, _streakData!).catchError((error) {
      D.p("BACKGROUND FIRESTORE BACKUP FAILED: $error");
    });

    setAvatar(_streakData!.currentStreak);
    notifyListeners();
  }

  Future<void> _checkAndCompleteMilestone(String? milestoneId) async {
    if (milestoneId == null) return;

    final dailyTasksForMilestone = await _repository.getSubTasks(milestoneId);

    if (dailyTasksForMilestone.where((t) => t.taskLevel == TaskLevelName.Daily).isEmpty) return;

    final allDailyTasksCompleted = dailyTasksForMilestone
        .where((t) => t.taskLevel == TaskLevelName.Daily)
        .every((t) => t.isDone);

    if (allDailyTasksCompleted) {
      final milestoneTask = await _repository.getTask(milestoneId);
      if (milestoneTask != null) {
        milestoneTask.isDone = true;
        milestoneTask.status = 'completed';
        await _repository.updateTask(milestoneTask);

        if (_activeMilestone?.id == milestoneId) {
          _activeMilestone = null;
        }
        notifyListeners();
      }
    }
  }
  
  Future<void> toggleTaskCompletion(TaskHiveModel task) async {
    if (task.dueDate == null || !isSameDay(task.dueDate!, DateTime.now())) {
      return;
    }

    task.isDone = !task.isDone;
    task.status = task.isDone ? "completed" : "pending";
    await _repository.updateTask(task);

    if (task.isDone) {
      await _updateStreakAndPoints();
      await _checkAndCompleteMilestone(task.parentTaskId);
    }

    if (_currentActiveGoal != null) {
      await _loadTasksForGoal(_currentActiveGoal!.id);
    }
  }

  Future<void> setTaskNotification(TaskHiveModel task, DateTime? notificationDateTime) async {
    task.notificationTime = notificationDateTime;

    if (notificationDateTime != null) {
      await NotificationService().scheduleTaskReminder(task: task);
    } else {
      await NotificationService().cancelTaskReminder(task.id);
    }
    
    await _repository.updateTask(task);
    if (_currentActiveGoal != null) {
      await _loadTasksForGoal(_currentActiveGoal!.id);
    }
  }

  List<TaskHiveModel> getTasksForDay(DateTime day) {
    return _calendarTasks[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  void toggleGoalCreationAvailability(bool availability) {
    _goalAvailability = availability;
    notifyListeners();
  }
  
  Future<void> addManualTask(TaskHiveModel newTask) async {
    await _repository.updateTask(newTask);
    if (_currentActiveGoal != null) {
      await _loadTasksForGoal(_currentActiveGoal!.id);
    }
  }
}