// aisupport/DashBoard_MapTask/Repository_AIRoadMap.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/repository/task_repository.dart';
import 'package:moneymanager/security/uid.dart'; // Assuming userId is available here

class AIFinanceRepository {
  final PlanRepository _localPlanRepository;
  final FirebaseFirestore _firestore;

  AIFinanceRepository({
    required PlanRepository localPlanRepository,
    FirebaseFirestore? firestore,
  })  : _localPlanRepository = localPlanRepository,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Backs up an entire plan (goal + all tasks) to Firestore.
  Future<void> backupPlanToFirestore(List<TaskHiveModel> tasks) async {
    if (tasks.isEmpty) return;

    final goalTask = tasks.firstWhere((t) => t.taskLevel == TaskLevelName.Goal, orElse: () => throw Exception("No Goal Task found to back up"));
    final String currentUserId = userId.uid; // Assumes you have the user's ID

    final WriteBatch batch = _firestore.batch();

    // 1. Set the main goal document
    final goalDocRef = _firestore
        .collection('financialGoals')
        .doc(currentUserId)
        .collection('goals')
        .doc(goalTask.id);
    batch.set(goalDocRef, _taskToFirestoreMap(goalTask));

    // 2. Set all the sub-task documents in the subcollection
    for (final task in tasks) {
      if (task.taskLevel != TaskLevelName.Goal) {
        final taskDocRef = goalDocRef.collection('tasks').doc(task.id);
        batch.set(taskDocRef, _taskToFirestoreMap(task));
      }
    }

    // 3. Commit the batch write
    await batch.commit();
  }

  /// Helper to convert a TaskHiveModel to a Firestore-compatible Map.
  Map<String, dynamic> _taskToFirestoreMap(TaskHiveModel task) {
    return {
      'id': task.id,
      'taskLevel': task.taskLevel.toString().split('.').last, // Store enum as string
      'parentTaskId': task.parentTaskId,
      'title': task.title,
      'purpose': task.purpose,
      'duration': task.duration,
      'isDone': task.isDone,
      'order': task.order,
      'createdAt': Timestamp.fromDate(task.createdAt), // Convert DateTime to Timestamp
      'dueDate': task.dueDate != null ? Timestamp.fromDate(task.dueDate!) : null,
      'status': task.status,
      // User input fields
      'userInputEarnTarget': task.userInputEarnTarget,
      'userInputDuration': task.userInputDuration,
      'userInputCurrentSkill': task.userInputCurrentSkill,
      'userInputPreferToEarnMoney': task.userInputPreferToEarnMoney,
      'userInputNote': task.userInputNote,
      'goalId': task.goalId,
    };
  }

  // [NEW] Helper to convert Firestore map to TaskHiveModel
  TaskHiveModel _taskFromFirestoreMap(Map<String, dynamic> data, String docId) {
    // Helper to safely parse enum from string
    TaskLevelName _parseTaskLevel(String? levelStr) {
      if (levelStr == null) return TaskLevelName.Daily; // or some default
      return TaskLevelName.values.firstWhere(
        (e) => e.toString().split('.').last == levelStr,
        orElse: () => TaskLevelName.Daily,
      );
    }
    
    return TaskHiveModel(
      id: docId,
      taskLevel: _parseTaskLevel(data['taskLevel']),
      parentTaskId: data['parentTaskId'],
      title: data['title'] ?? 'Untitled',
      purpose: data['purpose'],
      duration: data['duration'] ?? 'N/A',
      isDone: data['isDone'] ?? false,
      order: data['order'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      status: data['status'],
      userInputEarnTarget: data['userInputEarnTarget'],
      userInputDuration: data['userInputDuration'],
      userInputCurrentSkill: data['userInputCurrentSkill'],
      userInputPreferToEarnMoney: data['userInputPreferToEarnMoney'],
      userInputNote: data['userInputNote'],
      goalId: data['goalId'],
    );
  }

  Future<List<TaskHiveModel>> syncAndGetGoalTasks() async {
    List<TaskHiveModel> localGoals = await _localPlanRepository.getGoalTasks();
    if (localGoals.isNotEmpty) {
      return localGoals;
    }
    try {
      final remoteTasks = await _fetchAllTasksFromFirestore(userId.uid);
      if (remoteTasks.isNotEmpty) {
        await _localPlanRepository.saveAllTasks(remoteTasks);
        return remoteTasks.where((t) => t.taskLevel == TaskLevelName.Goal).toList();
      }
    } catch (e) {
      print("Failed to fetch or sync from remote source: $e");
    }

    return []; // Return empty if nothing found
  }

  /// [NEW] Fetches all goals and their subtasks from Firestore for a user.
  Future<List<TaskHiveModel>> _fetchAllTasksFromFirestore(String userId) async {
    final List<TaskHiveModel> allTasks = [];
    final goalsSnapshot = await _firestore
        .collection('financialGoals')
        .doc(userId)
        .collection('goals')
        .get();

    for (final goalDoc in goalsSnapshot.docs) {
      allTasks.add(_taskFromFirestoreMap(goalDoc.data(), goalDoc.id));
      final tasksSnapshot = await goalDoc.reference.collection('tasks').get();
      for (final taskDoc in tasksSnapshot.docs) {
        allTasks.add(_taskFromFirestoreMap(taskDoc.data(), taskDoc.id));
      }
    }
    return allTasks;
  }
  
  // ===================================================================
  // [MODIFIED] Deletion logic to handle both local and remote.
  // ===================================================================

  /// Deletes a Goal and all of its subtasks from local and remote storage.
  Future<void> deleteGoalAndAllSubTasks(String goalTaskId) async {
    final String currentUserId = userId.uid;
    final goalDocRef = _firestore
        .collection('financialGoals')
        .doc(currentUserId)
        .collection('goals')
        .doc(goalTaskId);

    final WriteBatch batch = _firestore.batch();
    
    // Efficiently get all sub-task documents to delete them
    final tasksSnapshot = await goalDocRef.collection('tasks').get();
    for (final doc in tasksSnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(goalDocRef);

    // Commit remote deletion first
    await batch.commit();

    // Then delete locally
    await _localPlanRepository.deleteGoalAndAllSubTasks(goalTaskId);
  }

  /// Deletes a single task and its children (if any).
  Future<void> deleteTaskWithSubtasks(TaskHiveModel taskToDelete) async {
      // Get all children that need to be deleted
      final allTasksToDelete = await _localPlanRepository.getAllSubTasksRecursive(taskToDelete.id);
      allTasksToDelete.add(taskToDelete); // Add the parent task itself

      final goalId = taskToDelete.goalId;
      if (goalId == null) {
          // This case should be rare with the new goalId logic, but as a fallback, only delete locally.
          await _localPlanRepository.deleteTask(taskToDelete.id, recursive: true);
          return;
      }
      
      final String currentUserId = userId.uid;
      final goalDocRef = _firestore.collection('financialGoals').doc(currentUserId).collection('goals').doc(goalId);
      final WriteBatch batch = _firestore.batch();

      for (final task in allTasksToDelete) {
          // Goals are not in the 'tasks' subcollection, handle separately
          if (task.taskLevel != TaskLevelName.Goal) {
              final taskDocRef = goalDocRef.collection('tasks').doc(task.id);
              batch.delete(taskDocRef);
          }
      }
      
      await batch.commit();

      // Finally, perform the local deletion
      await _localPlanRepository.deleteTask(taskToDelete.id, recursive: true);
  }


  // ===================================================================
  // [ADDED] Methods delegated to the local PlanRepository
  // The ViewModel will call these methods on this repository.
  // ===================================================================
  
  Future<List<TaskHiveModel>> getGoalTasks() {
      return _localPlanRepository.getGoalTasks();
  }

  Future<List<TaskHiveModel>> getSubTasks(String parentId) {
    return _localPlanRepository.getSubTasks(parentId);
  }

  Future<void> updateTask(TaskHiveModel task) {
    // Also update in firestore
     backupPlanToFirestore([task]);
    return _localPlanRepository.updateTask(task);
  }

  Future<void> saveAllTasks(List<TaskHiveModel> tasks) {
    return _localPlanRepository.saveAllTasks(tasks);
  }
  
  Future<void> deleteTask(String taskId, {bool recursive = true}) {
    return _localPlanRepository.deleteTask(taskId, recursive: recursive);
  }
}