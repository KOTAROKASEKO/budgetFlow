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

    // This line was causing the crash, but it's correct when saving a full plan.
    final goalTask = tasks.firstWhere((t) => t.taskLevel == TaskLevelName.Goal, orElse: () => throw Exception("No Goal Task found to back up"));
    final String currentUserId = userId.uid;

    final WriteBatch batch = _firestore.batch();

    final goalDocRef = _firestore
        .collection('financialGoals')
        .doc(currentUserId)
        .collection('goals')
        .doc(goalTask.id);
    batch.set(goalDocRef, _taskToFirestoreMap(goalTask));

    for (final task in tasks) {
      if (task.taskLevel != TaskLevelName.Goal) {
        final taskDocRef = goalDocRef.collection('tasks').doc(task.id);
        batch.set(taskDocRef, _taskToFirestoreMap(task));
      }
    }
    await batch.commit();
  }

  Map<String, dynamic> _taskToFirestoreMap(TaskHiveModel task) {
    return {
      'id': task.id,
      'taskLevel': task.taskLevel.toString().split('.').last,
      'parentTaskId': task.parentTaskId,
      'title': task.title,
      'purpose': task.purpose,
      'duration': task.duration,
      'isDone': task.isDone,
      'order': task.order,
      'createdAt': Timestamp.fromDate(task.createdAt),
      'dueDate': task.dueDate != null ? Timestamp.fromDate(task.dueDate!) : null,
      'status': task.status,
      'userInputEarnTarget': task.userInputEarnTarget,
      'userInputDuration': task.userInputDuration,
      'userInputCurrentSkill': task.userInputCurrentSkill,
      'userInputPreferToEarnMoney': task.userInputPreferToEarnMoney,
      'userInputNote': task.userInputNote,
      'goalId': task.goalId,
    };
  }

  TaskHiveModel _taskFromFirestoreMap(Map<String, dynamic> data, String docId) {
    TaskLevelName parseTaskLevel(String? levelStr) {
      if (levelStr == null) return TaskLevelName.Daily;
      return TaskLevelName.values.firstWhere(
        (e) => e.toString().split('.').last == levelStr,
        orElse: () => TaskLevelName.Daily,
      );
    }
    
    return TaskHiveModel(
      id: docId,
      taskLevel: parseTaskLevel(data['taskLevel']),
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

    return [];
  }

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
  
  Future<void> deleteGoalAndAllSubTasks(String goalTaskId) async {
    final String currentUserId = userId.uid;
    final goalDocRef = _firestore
        .collection('financialGoals')
        .doc(currentUserId)
        .collection('goals')
        .doc(goalTaskId);

    final WriteBatch batch = _firestore.batch();
    
    final tasksSnapshot = await goalDocRef.collection('tasks').get();
    for (final doc in tasksSnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(goalDocRef);

    await batch.commit();

    await _localPlanRepository.deleteGoalAndAllSubTasks(goalTaskId);
  }

  Future<void> deleteTaskWithSubtasks(TaskHiveModel taskToDelete) async {
      final allTasksToDelete = await _localPlanRepository.getAllSubTasksRecursive(taskToDelete.id);
      allTasksToDelete.add(taskToDelete);

      final goalId = taskToDelete.goalId;
      if (goalId == null) {
          await _localPlanRepository.deleteTask(taskToDelete.id, recursive: true);
          return;
      }
      
      final String currentUserId = userId.uid;
      final goalDocRef = _firestore.collection('financialGoals').doc(currentUserId).collection('goals').doc(goalId);
      final WriteBatch batch = _firestore.batch();

      for (final task in allTasksToDelete) {
          if (task.taskLevel != TaskLevelName.Goal) {
              final taskDocRef = goalDocRef.collection('tasks').doc(task.id);
              batch.delete(taskDocRef);
          }
      }
      
      await batch.commit();
      await _localPlanRepository.deleteTask(taskToDelete.id, recursive: true);
  }
  
  Future<List<TaskHiveModel>> getGoalTasks() {
      return _localPlanRepository.getGoalTasks();
  }

  Future<List<TaskHiveModel>> getSubTasks(String parentId) {
    return _localPlanRepository.getSubTasks(parentId);
  }

  // --- THIS IS THE CORRECTED METHOD ---
  Future<void> updateTask(TaskHiveModel task) async {
    final String currentUserId = userId.uid;

    // A Goal's goalId is its own id. A sub-task should already have it.
    final goalId = task.goalId ?? (task.taskLevel == TaskLevelName.Goal ? task.id : null);

    // If for some reason we can't find the goalId, we can't update Firestore.
    // Fallback to only updating the local database to prevent a crash.
    if (goalId == null) {
      print("Error: Cannot update task in Firestore without a goalId. Updating locally only.");
      await _localPlanRepository.updateTask(task);
      return;
    }

    final DocumentReference docRef;

    if (task.taskLevel == TaskLevelName.Goal) {
      // This is a top-level goal document
      docRef = _firestore
          .collection('financialGoals')
          .doc(currentUserId)
          .collection('goals')
          .doc(goalId);
    } else {
      // This is a sub-task document inside a goal's 'tasks' sub-collection
      docRef = _firestore
          .collection('financialGoals')
          .doc(currentUserId)
          .collection('goals')
          .doc(goalId)
          .collection('tasks')
          .doc(task.id);
    }

    // Update the specific document in Firestore.
    // Using .set with merge:true will create the document if it doesn't exist or update it if it does.
    await docRef.set(_taskToFirestoreMap(task), SetOptions(merge: true));

    // Finally, update the task in the local Hive database.
    await _localPlanRepository.updateTask(task);
  }

  Future<void> saveAllTasks(List<TaskHiveModel> tasks) {
    return _localPlanRepository.saveAllTasks(tasks);
  }
  
  Future<void> deleteTask(String taskId, {bool recursive = true}) {
    return _localPlanRepository.deleteTask(taskId, recursive: recursive);
  }
}