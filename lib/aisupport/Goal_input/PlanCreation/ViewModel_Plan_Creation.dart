// aisupport/Goal_input/PlanCreation/ViewModel_Plan_Creation.dart

import 'package:flutter/material.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/Repository_DashBoard.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/aiplanning_service.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';

// [REMOVED] No longer need to import PlanRepository directly
// import 'package:moneymanager/aisupport/Goal_input/PlanCreation/repository/task_repository.dart';

class PlanCreationViewModel extends ChangeNotifier {
  // [MODIFIED] Only the AIFinanceRepository is needed now.
  final AIFinanceRepository _repository;
  
  // [REMOVED] The direct link to PlanRepository is gone.
  // final PlanRepository _planRepository;

  AIPlanningService? _aiService;

  String _earnThisYear = '';
  String _planDuration = '';
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
  String get planUserDuration => _planDuration;


  PlanCreationViewModel({
    // [MODIFIED] Simplified constructor
    required AIFinanceRepository repository,
    TaskHiveModel? existingPlanRootTask,
    String? initialEarnThisYear,
    String? initialPlanDuration,
    String? initialCurrentSkill,
    String? initialPreferToEarnMoney,
    String? initialNote,
  }) : _repository = repository, // [MODIFIED]
       _existingPlanRootForRefinement = existingPlanRootTask {
    if (_existingPlanRootForRefinement != null) {
      _loadExistingPlanForRefinement(_existingPlanRootForRefinement!);
    } else if (initialPlanDuration != null) {
      initializeWithInputs(
        earnThisYear: initialEarnThisYear!,
        planDuration: initialPlanDuration,
        currentSkill: initialCurrentSkill!,
        preferToEarnMoney: initialPreferToEarnMoney!,
        note: initialNote!,
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
    required String planDuration,
    required String currentSkill,
    required String preferToEarnMoney,
    required String note,
  }) {
    _earnThisYear = earnThisYear;
    _planDuration = planDuration;
    _currentSkill = currentSkill;
    _preferToEarnMoney = preferToEarnMoney;
    _note = note;
    _goalName = "My Plan for $_planDuration";

    _aiService = AIPlanningService(
      earnThisYear: _earnThisYear,
      planDuration: _planDuration,
      currentSkill: _currentSkill,
      preferToEarnMoney: _preferToEarnMoney,
      note: _note,
    );

    _currentGoalTask = TaskHiveModel(
      taskLevel: TaskLevelName.Goal,
      title: _goalName,
      duration: _planDuration,
      order: 0,
      userInputEarnTarget: _earnThisYear,
      userInputDuration: _planDuration,
      userInputCurrentSkill: _currentSkill,
      userInputPreferToEarnMoney: _preferToEarnMoney,
      userInputNote: _note,
    );
    // [MODIFIED] A goal's goalId is its own id.
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
    _planDuration = rootGoalTask.userInputDuration ?? _currentGoalTask!.duration;
    _currentSkill = rootGoalTask.userInputCurrentSkill ?? '';
    _preferToEarnMoney = rootGoalTask.userInputPreferToEarnMoney ?? '';
    _note = rootGoalTask.userInputNote ?? '';

    _aiService = AIPlanningService(
      earnThisYear: _earnThisYear,
      planDuration: _planDuration,
      currentSkill: _currentSkill,
      preferToEarnMoney: _preferToEarnMoney,
      note: _note,
    );

    _taskHierarchy.clear();
    _selectedTasksAtLevel.clear();
    _childrenCache.clear();

    // [MODIFIED] Call getSubTasks via the main repository
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
        }
        _childrenCache[parentTask.id] = List.from(newSubTasks);
        tasksForHierarchy = newSubTasks;
      } else {
        if (_childrenCache.containsKey(parentTask.id)) {
          tasksForHierarchy = _childrenCache[parentTask.id]!;
        } else {
          // [MODIFIED] Call getSubTasks via the main repository
          List<TaskHiveModel> childrenFromDb = await _repository.getSubTasks(parentTask.id);
          if (childrenFromDb.isNotEmpty) {
            _childrenCache[parentTask.id] = List.from(childrenFromDb);
            tasksForHierarchy = childrenFromDb;
          } else{
            final List<TaskHiveModel> newSubTasks = await _aiService!.fetchAIPlan(
              parentTask: parentTask,
              additionalUserInstruction: null,
            );
            for (var subTask in newSubTasks) {
                subTask.parentTaskId = parentTask.id;
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

  // [MODIFIED] This entire function is updated for correctness.
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

      // Gather all children from the cache to save
      for (final children in _childrenCache.values) {
        tasksToSave.addAll(children);
      }
      
      // 1. Save all tasks locally via the main repository
      await _repository.saveAllTasks(tasksToSave);

      // 2. [ADDED] After local save succeeds, back up to Firebase
      try {
        await _repository.backupPlanToFirestore(tasksToSave);
        print("Plan successfully backed up to Firebase.");
      } catch (e) {
        // Log the Firebase backup error but don't fail the whole operation.
        // The local save was successful, which is the most important part.
        print("Firebase backup failed, but local save succeeded: $e");
        // Optionally, show a non-blocking message to the user
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
        for (int i = _taskHierarchy.length -1; i >= 0; i--) { 
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