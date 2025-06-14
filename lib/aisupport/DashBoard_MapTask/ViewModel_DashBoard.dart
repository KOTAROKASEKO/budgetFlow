// lib/aisupport/DashBoard_MapTask/ViewModel_AIRoadMap.dart

import 'package:flutter/material.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/Repository_DashBoard.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/streak/streak_hive_model.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/streak/streak_repository.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/notes/note_veiwmodel.dart';
import 'package:moneymanager/notification_service/notification_service.dart';
import 'package:moneymanager/security/uid.dart';
import 'package:table_calendar/table_calendar.dart';

class AIFinanceViewModel extends ChangeNotifier {
  final AIFinanceRepository _repository;
  final NoteViewModel noteViewModel;
  final StreakRepository _streakRepository;

  AIFinanceViewModel(
      {required this.noteViewModel,
      required AIFinanceRepository repository,
      required StreakRepository streakRepository})
      : _repository = repository,
        _streakRepository = streakRepository {
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

  bool _goalAvailability = false;
  bool get goalAvailability => _goalAvailability;

  StreakHiveModel? _streakData;
  StreakHiveModel? get streakData => _streakData;

  static const Map<int, int> _streakPoints = {
    1: 1,
    2: 1,
    3: 3,
    4: 1,
    5: 6,
    6: 10,
    7: 100
  };

  String _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image0.png?alt=media&token=f2e3b0df-dfc7-4343-b990-7786a21877f5'; // [修正] パスを修正
  String get picUrl => _picUrl;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setAvatar(int streakDay) {
    // [修正] アセットのパスを修正
    switch (streakDay) {
      case 1:
        _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image0.png?alt=media&token=f2e3b0df-dfc7-4343-b990-7786a21877f5';
        break;
      case 2:
        _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image2.png?alt=media&token=3702a196-97fc-4d53-a12c-621c9a49f560';
        break;
      case 3:
        _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image3.png?alt=media&token=92ac97b2-4022-447c-acff-a9c627d07006';
        break;
      case 4:
        _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image4.png?alt=media&token=36028ffa-f4fa-420f-a196-b95e6a38452c';
        break;
      case 5:
        _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image5.png?alt=media&token=b5b289f8-2824-404f-997a-9095f0149414';
        break;
      case 6:
        _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image6.png?alt=media&token=7e20cf65-0b69-4358-8f90-9b049aa92894';
        break;
      case 7:
        _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image7.png?alt=media&token=395049d4-1795-4801-9cf7-d8b58f5c968c';
        break;
      default:
        _picUrl = 'https://firebasestorage.googleapis.com/v0/b/assignment-64e6a.firebasestorage.app/o/image0.png?alt=media&token=f2e3b0df-dfc7-4343-b990-7786a21877f5';
    }
    notifyListeners();
  }

  Future<void> loadInitialData() async {
    _setLoading(true);
    await _loadAndCheckStreak();

    // [追加] 最初にアバターを設定する
    setAvatar(_streakData?.currentStreak ?? 0);

    final goals = await _repository.syncAndGetGoalTasks();
    if (goals.isNotEmpty) {
      _currentActiveGoal = goals.first;
      await _loadTasksForGoal(_currentActiveGoal!.id);
      if (_selectedDay != null) {
        noteViewModel.loadNoteForDay(_selectedDay!, _currentActiveGoal!.id);
      }
      toggleGoalCreationPossibility(false);
    } else {
      _currentActiveGoal = null;
      _draggableDailyTasks.clear();
      _calendarTasks.clear();
      noteViewModel.clearCurrentNote();
      toggleGoalCreationPossibility(true);
    }
    _setLoading(false);
  }

  Future<void> _loadAndCheckStreak() async {
    _streakData = await _streakRepository.getStreak();
    if (_streakData == null) {
      _streakData = StreakHiveModel.initial();
      await _streakRepository.saveStreak(_streakData!);
    }

    final lastDate = _streakData!.lastCompletionDate;
    if (lastDate == null) return;

    final today =
        DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final daysDifference = today.difference(lastDate).inDays;

    if (daysDifference > 1) {
      bool wasTaskMissed = false;
      for (int i = 1; i < daysDifference; i++) {
        final checkDate = lastDate.add(Duration(days: i));
        final tasksOnMissedDay = getTasksForDay(checkDate);
        if (tasksOnMissedDay.isNotEmpty) {
          wasTaskMissed = true;
          break;
        }
      }

      if (wasTaskMissed) {
        _streakData!.currentStreak = 0;
        await _streakRepository.saveStreak(_streakData!);
      }
    }
    notifyListeners();
  }

  Future<void> _loadTasksForGoal(String goalId) async {
    final allSubTasks = await _fetchAllSubTasksRecursive(goalId);
    final dailyTasks =
        allSubTasks.where((task) => task.taskLevel == TaskLevelName.Daily).toList();

    final newCalendarTasks = <DateTime, List<TaskHiveModel>>{};
    final newDraggableTasks = <TaskHiveModel>[];

    for (var task in dailyTasks) {
      if (task.dueDate != null) {
        final dateKey =
            DateTime.utc(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
        newCalendarTasks.putIfAbsent(dateKey, () => []).add(task);
      }
      if (task.dueDate == null) {
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

  Future<void> handleTaskDroppedOnCalendar(
      TaskHiveModel task, DateTime date) async {
    task.dueDate = DateTime.utc(date.year, date.month, date.day);
    task.status = 'scheduled_on_calendar';
    await _repository.updateTask(task);
    await NotificationService().scheduleTaskReminder(
      task: task,
      scheduledDate: date,
    );
    if (_currentActiveGoal != null) {
      await _loadTasksForGoal(_currentActiveGoal!.id);
    }
  }

  Future<void> returnTaskToDraggableList(TaskHiveModel task) async {
    await NotificationService().cancelTaskReminder(task.id);
    task.dueDate = null;
    task.status = 'pending';
    await _repository.updateTask(task);
    if (_currentActiveGoal != null) {
      await _loadTasksForGoal(_currentActiveGoal!.id);
    }
  }

  Future<void> _updateStreakAndPoints() async {
    if (_streakData == null) await _loadAndCheckStreak();

    final today =
        DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final lastDate = _streakData!.lastCompletionDate;

    if (lastDate != null && isSameDay(lastDate, today)) {
      return;
    }

    final yesterday = today.subtract(const Duration(days: 1));

    if (lastDate != null && isSameDay(lastDate, yesterday)) {
      _streakData!.currentStreak++;
    } else {
      _streakData!.currentStreak = 1;
    }

    if (_streakData!.currentStreak > 7) {
      _streakData!.currentStreak = 1;
    }

    final pointsToAdd = _streakPoints[_streakData!.currentStreak] ?? 0;
    _streakData!.totalPoints += pointsToAdd;
    _streakData!.lastCompletionDate = today;

    // Save locally first
    await _streakRepository.saveStreak(_streakData!);
    //This is not await because streak data can be updated often
       _streakRepository.saveStreakToFirestore(userId.uid, _streakData!)
      .catchError((error) {
        print("BACKGROUND FIRESTORE BACKUP FAILED: $error");
      });
    // ---------------------------------------------

    setAvatar(_streakData!.currentStreak);

    notifyListeners();
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
    }

    if (_currentActiveGoal != null) {
      await _loadTasksForGoal(_currentActiveGoal!.id);
    }
  }

  List<TaskHiveModel> getTasksForDay(DateTime day) {
    return _calendarTasks[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  void toggleGoalCreationPossibility(bool availability) {
    _goalAvailability = availability;
    notifyListeners();
  }
}