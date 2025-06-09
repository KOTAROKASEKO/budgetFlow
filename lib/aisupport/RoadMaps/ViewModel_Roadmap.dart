// File: lib/aisupport/viewmodel/roadmap_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/repository/task_repository.dart';

class RoadmapViewModel extends ChangeNotifier {
  final PlanRepository _planRepository;

  List<TaskHiveModel> _goalTasks = [];
  List<TaskHiveModel> get goalTasks => _goalTasks;

  List<Map<String, dynamic>> _navigationStack = []; // Stores {id: String, name: String, levelName: TaskLevelName}
  List<TaskHiveModel> _currentLevelItems = [];
  
  List<TaskHiveModel> get currentLevelItems => _currentLevelItems;
  List<Map<String, dynamic>> get navigationStack => _navigationStack;
  TaskHiveModel? get currentlyViewedGoalRoot {
    if (_navigationStack.isEmpty) return null;
    // The first item in the stack is always the Goal task for the current plan being viewed
    final goalId = _navigationStack.first['id'];
    // ignore: null_check_always_fails
    return _goalTasks.firstWhere((g) => g.id == goalId, orElse: () => _currentLevelItems.firstWhere((task) => task.id == goalId && task.taskLevel == TaskLevelName.Goal, orElse: () => null!));
  }


  bool _isLoading = false;
  String? _errorMessage;

  // --- NEW ---
  bool _isDisposed = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  RoadmapViewModel({required PlanRepository planRepository}) : _planRepository = planRepository {
    loadGoalTasks();
  }

  // --- NEW ---
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _setLoading(bool loading) {
    if (_isDisposed) return; // Prevent calls after dispose
    _isLoading = loading;
    if(loading) _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    if (_isDisposed) return; // Prevent calls after dispose
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadGoalTasks() async {
    _setLoading(true);
    _navigationStack.clear();
    _currentLevelItems.clear();
    try {
      _goalTasks = await _planRepository.getGoalTasks();
      if (_goalTasks.isEmpty) _errorMessage = "No financial plans found. Create one!";
    } catch (e) {
      _setError("Failed to load plans: ${e.toString()}");
    } finally {
        _setLoading(false);
    }
  }

  Future<void> navigateToTaskChildren(TaskHiveModel task) async {
    _setLoading(true);
    _navigationStack.add({'id': task.id, 'name': task.title, 'levelName': task.taskLevel});
    try {
      _currentLevelItems = await _planRepository.getSubTasks(task.id);
      if (_currentLevelItems.isEmpty) _errorMessage = "This item has no sub-tasks.";
    } catch (e) {
      _setError("Failed to load sub-tasks for ${task.title}: ${e.toString()}");
    } finally {
        _setLoading(false);
    }
  }

  Future<bool> goBack() async {
    if (_navigationStack.isNotEmpty) {
      _setLoading(true);
      _navigationStack.removeLast();
      _errorMessage = null; // Clear previous error on navigation
      if (_navigationStack.isEmpty) {
        _currentLevelItems.clear(); // Back to the main goal list
        _setLoading(false);
      } else {
        final parent = _navigationStack.last;
        try {
          _currentLevelItems = await _planRepository.getSubTasks(parent['id']);
           if (_currentLevelItems.isEmpty) _errorMessage = "No sub-tasks found for ${parent['name']}.";
        } catch (e) {
          _setError("Failed to load items for ${parent['name']}: ${e.toString()}");
        } finally {
           _setLoading(false);
        }
      }
      return false; // Handled navigation
    }
    return true; // Allow system back
  }
  


  Future<void> editTask(TaskHiveModel taskToEdit, String newTitle, String? newPurpose, String newDuration) async {
    _setLoading(true);
    taskToEdit.title = newTitle;
    taskToEdit.purpose = newPurpose;
    taskToEdit.duration = newDuration;
    try {
      await _planRepository.updateTask(taskToEdit);
      // Refresh current level's items or goal list
      if (_navigationStack.isEmpty) { // Editing a top-level goal
        await loadGoalTasks();
      } else {
        final parentId = _navigationStack.last['id'];
        _currentLevelItems = await _planRepository.getSubTasks(parentId);
      }
    } catch (e) {
      _setError("Failed to update task: ${e.toString()}");
    } finally {
        _setLoading(false);
    }
  }

  Future<void> deleteTask(TaskHiveModel taskToDelete) async {
    _setLoading(true);
    try {
      if (taskToDelete.taskLevel == TaskLevelName.Goal) {
        await _planRepository.deleteGoalAndAllSubTasks(taskToDelete.id);
        await loadGoalTasks(); // Refresh the main list of goals
        
      } else {
        await _planRepository.deleteTask(taskToDelete.id, recursive: true);
        // Refresh the current view:
        if (_navigationStack.isNotEmpty) {
          final parentId = _navigationStack.last['id'];
          _currentLevelItems = await _planRepository.getSubTasks(parentId);
          if(_currentLevelItems.isEmpty) _errorMessage = "No items left at this level.";
        } else { // Should not be reachable if not a Goal, but safeguard
          await loadGoalTasks();
        }
      }
    } catch (e) {
      _setError("Failed to delete task: ${e.toString()}");
    } finally {
      _setLoading(false);
    }
  }
}