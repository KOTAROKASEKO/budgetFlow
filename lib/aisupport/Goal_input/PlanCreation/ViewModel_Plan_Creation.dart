// aisupport/Goal_input/PlanCreation/ViewModel_Plan_Creation.dart

import 'package:flutter/material.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/Repository_DashBoard.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/AI_Service.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';

class PlanCreationViewModel extends ChangeNotifier {
  final AIFinanceRepository _repository;
  AIPlanningService? _aiService;

  String _earnThisYear = '';
  String _currentSkill = '';
  String _preferToEarnMoney = '';
  String _note = '';
  String _goalName = '';

  TaskHiveModel? _currentGoalTask; // The root Goal Task
  List<List<TaskHiveModel>> _taskHierarchy = [];
  Map<int, TaskHiveModel?> _selectedTasksAtLevel = {};
  final Map<String, List<TaskHiveModel>> _childrenCache = {};

  bool _isLoading = false;
  String? _errorMessage;
  final TaskHiveModel? _existingPlanRootForRefinement;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<List<TaskHiveModel>> get taskHierarchy => _taskHierarchy;
  TaskHiveModel? getSelectedTask(int level) => _selectedTasksAtLevel[level];
  TaskHiveModel? get currentGoalTask => _currentGoalTask;
  String get goalName => _goalName;
  set goalName(String name) {
    _goalName = name;
    if (_currentGoalTask != null) {
      _currentGoalTask!.title = name;
    }
    notifyListeners();
  }

  PlanCreationViewModel({
    required AIFinanceRepository repository,
    TaskHiveModel? existingPlanRootTask,
    required String initialEarnThisYear,
    required String initialCurrentSkill,
    required String initialPreferToEarnMoney,
    required String initialNote,
  }) : _repository = repository,
       _existingPlanRootForRefinement = existingPlanRootTask {
    if (_existingPlanRootForRefinement != null) {
      _loadExistingPlanForRefinement(_existingPlanRootForRefinement);
    } else {
      initializeWithInputs(
        earnThisYear: initialEarnThisYear,
        currentSkill: initialCurrentSkill,
        preferToEarnMoney: initialPreferToEarnMoney,
        note: initialNote,
      );
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }

  void initializeWithInputs({
    required String earnThisYear,
    required String currentSkill,
    required String preferToEarnMoney,
    required String note,
  }) {
    _earnThisYear = earnThisYear;
    _currentSkill = currentSkill;
    _preferToEarnMoney = preferToEarnMoney;
    _note = note;
    _goalName = "My Plan to earn RM$earnThisYear";

    _aiService = AIPlanningService(
      earnThisYear: _earnThisYear,
      currentSkill: _currentSkill,
      preferToEarnMoney: _preferToEarnMoney,
      note: _note,
    );

    _currentGoalTask = TaskHiveModel(
      taskLevel: TaskLevelName.Goal,
      title: _goalName,
      duration: "N/A", // Duration is no longer relevant for the plan structure
      order: 0,
      userInputEarnTarget: _earnThisYear,
      userInputCurrentSkill: _currentSkill,
      userInputPreferToEarnMoney: _preferToEarnMoney,
      userInputNote: _note,
    );
    _currentGoalTask!.goalId = _currentGoalTask!.id;

    _taskHierarchy = [];
    _selectedTasksAtLevel = {};
    _childrenCache.clear();

    fetchOrBreakdownTasks(parentTask: _currentGoalTask!);
  }

  Future<void> _loadExistingPlanForRefinement(TaskHiveModel rootGoalTask) async {
    _setLoading(true);
    _currentGoalTask = rootGoalTask;
    _goalName = rootGoalTask.title;
    _earnThisYear = rootGoalTask.userInputEarnTarget ?? '';
    _currentSkill = rootGoalTask.userInputCurrentSkill ?? '';
    _preferToEarnMoney = rootGoalTask.userInputPreferToEarnMoney ?? '';
    _note = rootGoalTask.userInputNote ?? '';

    _aiService = AIPlanningService(
      earnThisYear: _earnThisYear,
      currentSkill: _currentSkill,
      preferToEarnMoney: _preferToEarnMoney,
      note: _note,
    );

    _taskHierarchy.clear();
    _selectedTasksAtLevel.clear();
    _childrenCache.clear();

    List<TaskHiveModel> firstLevelChildren = await _repository.getSubTasks(rootGoalTask.id);

    if (firstLevelChildren.isNotEmpty) {
      _childrenCache[rootGoalTask.id] = List.from(firstLevelChildren);
      _updateHierarchyWithTasks(firstLevelChildren, null);
    } else {
      await fetchOrBreakdownTasks(parentTask: _currentGoalTask!);
    }
    _setLoading(false);
  }

  void _selectTaskInternal(int level, TaskHiveModel? task) {
    _selectedTasksAtLevel[level] = task;
    
    int nextLevel = level + 1;
    if (nextLevel < _taskHierarchy.length) {
      for (int i = nextLevel; i < _taskHierarchy.length; i++) {
        for (var taskToRemove in _taskHierarchy[i]) {
          _childrenCache.remove(taskToRemove.id);
        }
      }
      _taskHierarchy.removeRange(nextLevel, _taskHierarchy.length);
    }
    _selectedTasksAtLevel.keys.where((k) => k > level).toList().forEach(_selectedTasksAtLevel.remove);

    if (task == null) {
      _selectedTasksAtLevel.remove(level);
    }
  }

  void selectTask(int level, TaskHiveModel? task) {
    _selectTaskInternal(level, task);
    notifyListeners();
  }

  Future<void> fetchOrBreakdownTasks({
    required TaskHiveModel parentTask,
    int? currentHierarchyLevel,
    String? additionalInstruction,
  }) async {
    if (_aiService == null) {
      _setError("AI Service not initialized.");
      return;
    }
    
    if (parentTask.taskLevel == TaskLevelName.Daily) {
       notifyListeners();
       return;
    }
    
    _setLoading(true);

    try {
      List<TaskHiveModel> tasksForHierarchy;
      if (additionalInstruction != null) {
        final List<TaskHiveModel> newSubTasks = await _aiService!.fetchAIPlan(
          parentTask: parentTask,
          additionalUserInstruction: additionalInstruction,
        );
        for (var subTask in newSubTasks) {
            subTask.parentTaskId = parentTask.id;
            subTask.goalId = parentTask.goalId; // Ensure goalId is passed down
        }
        _childrenCache[parentTask.id] = List.from(newSubTasks);
        tasksForHierarchy = newSubTasks;
      } else {
        if (_childrenCache.containsKey(parentTask.id)) {
          tasksForHierarchy = _childrenCache[parentTask.id]!;
        } else {
          List<TaskHiveModel> childrenFromDb = await _repository.getSubTasks(parentTask.id);
          if (childrenFromDb.isNotEmpty) {
            _childrenCache[parentTask.id] = List.from(childrenFromDb);
            tasksForHierarchy = childrenFromDb;
          } else{
            final List<TaskHiveModel> newSubTasks = await _aiService!.fetchAIPlan(
              parentTask: parentTask,
            );
            for (var subTask in newSubTasks) {
                subTask.parentTaskId = parentTask.id;
                subTask.goalId = parentTask.goalId; // Ensure goalId is passed down
            }
            _childrenCache[parentTask.id] = List.from(newSubTasks);
            tasksForHierarchy = newSubTasks;
          }
        }
      }
      _updateHierarchyWithTasks(tasksForHierarchy, currentHierarchyLevel);
    } catch (e) {
      _setError("Failed to get tasks for ${parentTask.title}: ${e.toString()}");
    } finally {
        _setLoading(false);
    }
  }

  void _updateHierarchyWithTasks(List<TaskHiveModel> newTasksForNextLevel, int? parentLevelInHierarchy) {
    int childLevel;
    if (parentLevelInHierarchy == null) {
        childLevel = 0;
        _taskHierarchy.clear();
        _selectedTasksAtLevel.clear();
        if (newTasksForNextLevel.isNotEmpty) {
            _taskHierarchy.add(newTasksForNextLevel);
        }
    } else {
        childLevel = parentLevelInHierarchy + 1;

        if (childLevel < _taskHierarchy.length) {
            _taskHierarchy.removeRange(childLevel, _taskHierarchy.length);
        }
        _selectedTasksAtLevel.keys.where((k) => k >= childLevel).toList().forEach(_selectedTasksAtLevel.remove);

        if (newTasksForNextLevel.isNotEmpty) {
             while (_taskHierarchy.length <= childLevel) {
                _taskHierarchy.add([]);
            }
            _taskHierarchy[childLevel] = newTasksForNextLevel;
        } else {
            if (childLevel < _taskHierarchy.length) {
                 _taskHierarchy[childLevel] = [];
            }
        }
    }

    if (childLevel < _taskHierarchy.length && _taskHierarchy[childLevel].isNotEmpty) {
        _selectTaskInternal(childLevel, _taskHierarchy[childLevel].first);
    } else {
        _selectedTasksAtLevel.remove(childLevel);
    }
  }

  Future<bool> savePlan() async {
    if (_currentGoalTask == null) {
      _setError("No goal to save.");
      return false;
    }
    if (_goalName.trim().isEmpty) {
      _setError("Please set a name for your goal.");
      return false;
    }
    _setLoading(true);

    try {
      final List<TaskHiveModel> tasksToSave = [];
      _currentGoalTask!.title = _goalName.trim();
      tasksToSave.add(_currentGoalTask!);

      for (final children in _childrenCache.values) {
        tasksToSave.addAll(children);
      }
      
      await _repository.saveAllTasks(tasksToSave);

      try {
        await _repository.backupPlanToFirestore(tasksToSave);
        print("Plan successfully backed up to Firebase.");
      } catch (e, s) { 
        print("--- FIRESTORE BACKUP FAILED ---");
        print("EXCEPTION: $e");
        print("STACK TRACE: $s");
        print("---------------------------------");
      }
      
      _childrenCache.clear();
      _setLoading(false);
      return true;

    } catch (e) {
      _setError("Failed to save plan: ${e.toString()}");
      _setLoading(false);
      return false;
    }
  }

  Future<void> regenerateTasksForSelectedParent(String? instruction) async {
    int? selectedLevelForParentContext;
    TaskHiveModel? parentTaskToRegenerateChildrenFor;

    if (_selectedTasksAtLevel.isEmpty && _currentGoalTask != null) {
        parentTaskToRegenerateChildrenFor = _currentGoalTask;
        selectedLevelForParentContext = null;
    } else {
        final int maxLevel = _selectedTasksAtLevel.keys.reduce((a, b) => a > b ? a : b);
        for (int i = maxLevel; i >= 0; i--) { 
            if (_selectedTasksAtLevel.containsKey(i) && _selectedTasksAtLevel[i] != null) {
                parentTaskToRegenerateChildrenFor = _selectedTasksAtLevel[i];
                selectedLevelForParentContext = i;
                break;
            }
        }
        if (parentTaskToRegenerateChildrenFor == null && _currentGoalTask != null) {
            parentTaskToRegenerateChildrenFor = _currentGoalTask;
            selectedLevelForParentContext = null;
        }
    }

    if (parentTaskToRegenerateChildrenFor != null) {
      await fetchOrBreakdownTasks(
          parentTask: parentTaskToRegenerateChildrenFor,
          currentHierarchyLevel: selectedLevelForParentContext,
          additionalInstruction: instruction
      );
    } else {
      _setError("No task context found to regenerate for, or no main goal initialized.");
    }
  }
}