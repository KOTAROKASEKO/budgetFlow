// File: lib/aisupport/repository/plan_repository.dart
import 'package:hive/hive.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';

class PlanRepository {
  static const String boxName = 'aiUserPlans_v3'; // Use a new box name

  Future<Box<TaskHiveModel>> _getBox() async {
    // Ensure adapters are registered before opening the box
    if (!Hive.isAdapterRegistered(TaskHiveModelAdapter().typeId)) {
      Hive.registerAdapter(TaskHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(TaskLevelNameAdapter().typeId)) {
      Hive.registerAdapter(TaskLevelNameAdapter());
    }
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox<TaskHiveModel>(boxName);
    }
    return Hive.box<TaskHiveModel>(boxName);
  }

  Future<void> initDb() async {
    await _getBox();
  }

  Future<void> saveTask(TaskHiveModel task) async {
    final box = await _getBox();
    await box.put(task.id, task);
  }

  Future<void> saveAllTasks(List<TaskHiveModel> tasks) async {
    final box = await _getBox();
    final Map<String, TaskHiveModel> taskMap = {for (var task in tasks) task.id: task};
    await box.putAll(taskMap);
  }

  Future<List<TaskHiveModel>> getAllTasks() async {
    final box = await Hive.openBox<TaskHiveModel>(boxName);
    return box.values.toList();
  }

  Future<List<TaskHiveModel>> getAllSubTasksRecursive(String parentTaskId) async {
    final List<TaskHiveModel> allSubTasks = [];
    final children = await getSubTasks(parentTaskId);
    for (final child in children) {
      allSubTasks.add(child);
      allSubTasks.addAll(await getAllSubTasksRecursive(child.id));
    }
    return allSubTasks;
  }

  Future<TaskHiveModel?> getTask(String taskId) async {
    final box = await _getBox();
    return box.get(taskId);
  }

  Future<List<TaskHiveModel>> getGoalTasks() async {
    final box = await _getBox();
    return box.values.where((task) => task.taskLevel == TaskLevelName.Goal && task.parentTaskId == null).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by newest first
  }

  Future<List<TaskHiveModel>> getSubTasks(String parentTaskId) async {
    final box = await _getBox();
    return box.values.where((task) => task.parentTaskId == parentTaskId).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> updateTask(TaskHiveModel task) async {
    await saveTask(task); // Hive's put handles updates
  }

  Future<void> deleteTask(String taskId, {bool recursive = true}) async {
    print('deleting...');
    final box = await _getBox();
    if (recursive) {
      final List<TaskHiveModel> children = await getSubTasks(taskId);
      for (final child in children) {
        print('deleted ${child.id}');
        await deleteTask(child.id, recursive: true);
      }
    }
    await box.delete(taskId);
  }
  
  Future<void> deleteGoalAndAllSubTasks(String goalTaskId) async {
    final goalTask = await getTask(goalTaskId);
    if (goalTask == null || goalTask.taskLevel != TaskLevelName.Goal) {
        print("Task ID $goalTaskId is not a Goal or does not exist for deletion.");
        return;
    }
    await deleteTask(goalTaskId, recursive: true);
  }
}