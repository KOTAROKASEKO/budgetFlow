// File: lib/aisupport/viewmodel/plan_creation_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/aiplanning_service.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/repository/task_repository.dart';

class PlanCreationViewModel extends ChangeNotifier {
  final PlanRepository _planRepository;
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
  Map<String, List<TaskHiveModel>> _childrenCache = {}; // Temporary cache for task children

  bool _isLoading = false;
  String? _errorMessage;
  TaskHiveModel? _existingPlanRootForRefinement;


  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<List<TaskHiveModel>> get taskHierarchy => _taskHierarchy;
  TaskHiveModel? getSelectedTask(int level) => _selectedTasksAtLevel[level];
  TaskHiveModel? get currentGoalTask => _currentGoalTask;
  String get goalName => _goalName;
  set goalName(String name) {
    _goalName = name;
    if (_currentGoalTask != null) {
      _currentGoalTask!.title = name; // Keep ViewModel's goal task title in sync
    }
    notifyListeners();
  }
  String get planUserDuration => _planDuration;


  PlanCreationViewModel({
    required PlanRepository planRepository,
    TaskHiveModel? existingPlanRootTask, // For refinement
    String? initialEarnThisYear,
    String? initialPlanDuration,
    String? initialCurrentSkill,
    String? initialPreferToEarnMoney,
    String? initialNote,
  }) : _planRepository = planRepository,
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
    _goalName = "My Plan for $_planDuration"; // Default

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
    _taskHierarchy = [];
    _selectedTasksAtLevel = {};
    _childrenCache.clear(); // Clear cache for a new plan

    // This will fetch tasks for level 0 and _updateHierarchyWithTasks will select the first one by default
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
    _childrenCache.clear(); // Clear cache when loading a new plan for refinement

    List<TaskHiveModel> firstLevelChildren = await _planRepository.getSubTasks(rootGoalTask.id);

    if (firstLevelChildren.isNotEmpty) {
      _childrenCache[rootGoalTask.id] = List.from(firstLevelChildren); // Populate cache
      _updateHierarchyWithTasks(firstLevelChildren, null); 
    } else {
      // If no children persisted, fetch from AI. This will also use _updateHierarchyWithTasks.
      // fetchOrBreakdownTasks will populate the cache.
      await fetchOrBreakdownTasks(parentTask: _currentGoalTask!);
    }
    _setLoading(false);
  }

  void selectTask(int level, TaskHiveModel? task) {
    _selectedTasksAtLevel[level] = task;

    int nextLevel = level + 1;
    if (nextLevel < _taskHierarchy.length) {
      _taskHierarchy.removeRange(nextLevel, _taskHierarchy.length);
    }
    _selectedTasksAtLevel.keys.where((k) => k > level).toList().forEach(_selectedTasksAtLevel.remove);

    if (task == null) {
        _selectedTasksAtLevel.remove(level);
    }
    notifyListeners();
  }

  Future<void> fetchOrBreakdownTasks({
    required TaskHiveModel parentTask,
    int? currentHierarchyLevel,
    String? additionalInstruction, // If not null, regeneration is requested
  }) async {

    print('level : ${parentTask.taskLevel}');
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
        // Regeneration requested: Fetch from AI and update cache
        final List<TaskHiveModel> newSubTasks = await _aiService!.fetchAIPlan(
          parentTask: parentTask,
          additionalUserInstruction: additionalInstruction,
        );
        for (var subTask in newSubTasks) {
            subTask.parentTaskId = parentTask.id;
        }
        _childrenCache[parentTask.id] = List.from(newSubTasks); // Update cache with new AI results
        tasksForHierarchy = newSubTasks;
      } else {
        // Not regenerating: Try cache, then DB, then AI
        if (_childrenCache.containsKey(parentTask.id)) {
          // Load from cache
          tasksForHierarchy = _childrenCache[parentTask.id]!;
        } else {
          // Not in cache, try DB
          List<TaskHiveModel> childrenFromDb = await _planRepository.getSubTasks(parentTask.id);
          if (childrenFromDb.isNotEmpty) {
            _childrenCache[parentTask.id] = List.from(childrenFromDb); // Cache DB result
            tasksForHierarchy = childrenFromDb;
          } else {
            // Not in DB, fetch from AI
            final List<TaskHiveModel> newSubTasks = await _aiService!.fetchAIPlan(
              parentTask: parentTask,
              additionalUserInstruction: null, // No specific instruction for first time
            );
            for (var subTask in newSubTasks) {
                subTask.parentTaskId = parentTask.id;
            }
            _childrenCache[parentTask.id] = List.from(newSubTasks); // Cache AI result
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
        _selectedTasksAtLevel[childLevel] = _taskHierarchy[childLevel].first;
    } else {
        _selectedTasksAtLevel.remove(childLevel);
    }
    // notifyListeners() is handled by the calling method (_setLoading(false) or _setError or notifyListeners() in selectTask)
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
    _currentGoalTask!.title = _goalName.trim(); 

    List<TaskHiveModel> allTasksToSave = [_currentGoalTask!];
    
    for (int i = 0; i < _taskHierarchy.length; i++) {
        allTasksToSave.addAll(_taskHierarchy[i]);
    }
    
    for(int level = 0; level < _taskHierarchy.length; level++){
        TaskHiveModel? parentForThisLevel;
        if(level == 0) { 
            parentForThisLevel = _currentGoalTask;
        } else { 
            parentForThisLevel = _selectedTasksAtLevel[level-1];
        }

        if(parentForThisLevel != null && level < _taskHierarchy.length){ 
            for(var taskInLevel in _taskHierarchy[level]){
                taskInLevel.parentTaskId = parentForThisLevel.id;
            }
        }
    }
    
    allTasksToSave = allTasksToSave.toSet().toList(); 

    try {
      await _planRepository.saveAllTasks(allTasksToSave);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError("Failed to save plan: ${e.toString()}");
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
        for (int i = _taskHierarchy.length -1; i >= 0; i--) { // Iterate from deepest selected level upwards
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
          additionalInstruction: instruction // This signals regeneration
      );
    } else {
      _setError("No task context found to regenerate for, or no main goal initialized.");
    }
  }
}