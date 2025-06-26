// aisupport/DashBoard_MapTask/Repository_AIRoadMap.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:moneymanager/aisupport/Goal_input/PlanCreation/repository/task_repository.dart';
import 'package:moneymanager/security/uid.dart';

class AIFinanceRepository {
  final PlanRepository _localPlanRepository;
  final FirebaseFirestore _firestore;

  AIFinanceRepository({
    required PlanRepository localPlanRepository,
    FirebaseFirestore? firestore,
  })  : _localPlanRepository = localPlanRepository,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Future<TaskHiveModel?> getTask(String taskId) {
    return _localPlanRepository.getTask(taskId);
  }

  Future<List<TaskHiveModel>> getAllTasks() {
    return _localPlanRepository.getAllTasks();
  }

  // UPDATED: This method is now more robust.
  Future<void> backupPlanToFirestore(List<TaskHiveModel> tasks) async {
    if (tasks.isEmpty) {
      print("No tasks provided to backupPlanToFirestore.");
      return;
    }

    final String currentUserId = userId.uid;
    if (currentUserId.isEmpty) {
      throw Exception("Cannot back up tasks: User is not logged in.");
    }
    
    // NEW LOGIC: Get goalId from the first task, as all tasks in a batch share it.
    final String? goalId = tasks.first.goalId;
    if (goalId == null || goalId.isEmpty) {
      throw Exception("Cannot back up tasks: goalId is missing from the tasks.");
    }

    final WriteBatch batch = _firestore.batch();

    // The path to the specific goal document.
    final goalDocRef = _firestore
        .collection('financialGoals')
        .doc(currentUserId)
        .collection('goals')
        .doc(goalId);

    for (final task in tasks) {
      // If the task is the main Goal itself, set it at the goal document level.
      if (task.taskLevel == TaskLevelName.Goal) {
        batch.set(goalDocRef, _taskToFirestoreMap(task));
      } else {
        // Otherwise, it's a sub-task (Phase, Milestone, Daily), so set it in the 'tasks' sub-collection.
        final taskDocRef = goalDocRef.collection('tasks').doc(task.id);
        batch.set(taskDocRef, _taskToFirestoreMap(task));
      }
    }

    print("Attempting to commit batch of ${tasks.length} tasks to Firestore for goalId: $goalId");
    await batch.commit();
    print("Batch commit successful.");
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
      'notificationTime': task.notificationTime != null ? Timestamp.fromDate(task.notificationTime!) : null,
      'subSteps': task.subSteps,
      'definitionOfDone': task.definitionOfDone,
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
      notificationTime: (data['notificationTime'] as Timestamp?)?.toDate(),
      subSteps: data['subSteps'] != null ? List<Map<String, dynamic>>.from(data['subSteps']) : null,
      definitionOfDone: data['definitionOfDone'] != null ? List<Map<String, dynamic>>.from(data['definitionOfDone']) : null,
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
        return remoteTasks
            .where((t) => t.taskLevel == TaskLevelName.Goal)
            .toList();
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
    final goalDocRef = _firestore.collection('financialGoals').doc(currentUserId).collection('goals').doc(goalTaskId);
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

  Future<void> updateTask(TaskHiveModel task) async {
    final String currentUserId = userId.uid;
    final goalId = task.goalId ?? (task.taskLevel == TaskLevelName.Goal ? task.id : null);

    if (goalId == null) {
      print("Error: Cannot update task in Firestore without a goalId. Updating locally only.");
      await _localPlanRepository.updateTask(task);
      return;
    }

    final DocumentReference docRef;
    if (task.taskLevel == TaskLevelName.Goal) {
      docRef = _firestore.collection('financialGoals').doc(currentUserId).collection('goals').doc(goalId);
    } else {
      docRef = _firestore.collection('financialGoals').doc(currentUserId).collection('goals').doc(goalId).collection('tasks').doc(task.id);
    }
    await docRef.set(_taskToFirestoreMap(task), SetOptions(merge: true));
    await _localPlanRepository.updateTask(task);
  }

  Future<void> saveAllTasks(List<TaskHiveModel> tasks) {
    return _localPlanRepository.saveAllTasks(tasks);
  }

  Future<void> deleteTask(String taskId, {bool recursive = true}) {
    return _localPlanRepository.deleteTask(taskId, recursive: recursive);
  }

  Future<void> deleteTaskWithChildren(String taskId) async {
    final box = await Hive.openBox<TaskHiveModel>(PlanRepository.boxName);
    final taskToDelete = await box.get(taskId);
    if(taskToDelete == null) return;
    await deleteTaskWithSubtasks(taskToDelete);
  }
}