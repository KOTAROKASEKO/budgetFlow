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
    return _goalTasks.firstWhere((g) => g.id == goalId, orElse: () => _currentLevelItems.firstWhere((task) => task.id == goalId && task.taskLevel == TaskLevelName.Goal, orElse: () => null!));
  }


  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  RoadmapViewModel({required PlanRepository planRepository}) : _planRepository = planRepository {
    loadGoalTasks();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    if(loading) _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
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
      _setLoading(false);
    } catch (e) {
      _setError("Failed to load plans: ${e.toString()}");
    }
  }

  Future<void> navigateToTaskChildren(TaskHiveModel task) async {
    _setLoading(true);
    _navigationStack.add({'id': task.id, 'name': task.title, 'levelName': task.taskLevel});
    try {
      _currentLevelItems = await _planRepository.getSubTasks(task.id);
      if (_currentLevelItems.isEmpty) _errorMessage = "This item has no sub-tasks.";
      _setLoading(false);
    } catch (e) {
      _setError("Failed to load sub-tasks for ${task.title}: ${e.toString()}");
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
          _setLoading(false);
        } catch (e) {
          _setError("Failed to load items for ${parent['name']}: ${e.toString()}");
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
      _setLoading(false);
    } catch (e) {
      _setError("Failed to update task: ${e.toString()}");
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
      _setLoading(false);
    } catch (e) {
      _setError("Failed to delete task: ${e.toString()}");
    }
  }
}