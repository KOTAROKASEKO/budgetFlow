// File: lib/aisupport/models/task_hive_model.dart
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'task_hive_model.g.dart'; // Remember to generate this file

var _uuid = Uuid();

@HiveType(typeId: 10)
enum TaskLevelName {
  @HiveField(0)
  Goal,
  @HiveField(1)
  Phase,
  @HiveField(2)
  Monthly,
  @HiveField(3)
  Weekly,
  @HiveField(4)
  Daily,
}

@HiveType(typeId: 11) // Ensure unique typeId
class TaskHiveModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  TaskLevelName taskLevel;

  @HiveField(2)
  String? parentTaskId;

  @HiveField(3)
  String title;

  @HiveField(4)
  String? purpose;

  @HiveField(5)
  String duration; // e.g., "6 months", "1 week"

  @HiveField(6)
  bool isDone;

  @HiveField(7)
  int order; // For display sequence among siblings

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime? dueDate; // Useful for Daily tasks and calendar integration

  @HiveField(10)
  String? status; // e.g., 'pending', 'scheduled_on_calendar', 'completed'

  // Store initial user inputs with the top-level Goal task
  @HiveField(11)
  String? userInputEarnTarget;

  @HiveField(12)
  String? userInputDuration; // The original duration string like "2 years"

  @HiveField(13)
  String? userInputCurrentSkill;

  @HiveField(14)
  String? userInputPreferToEarnMoney;

  @HiveField(15)
  String? userInputNote;

  // [NEW] Add goalId to easily find the root goal for any task.
  @HiveField(16)
  String? goalId;

  @HiveField(17)
  DateTime? notificationTime;

  @HiveField(18)
  List<Map<String, dynamic>>? subSteps;


  TaskHiveModel({
    String? id,
    required this.taskLevel,
    this.parentTaskId,
    required this.title,
    this.purpose,
    required this.duration,
    this.isDone = false,
    required this.order,
    DateTime? createdAt,
    this.dueDate,
    this.status = 'pending',
    this.userInputEarnTarget,
    this.userInputDuration,
    this.userInputCurrentSkill,
    this.userInputPreferToEarnMoney,
    this.userInputNote,
    this.goalId,
    this.notificationTime,
    this.subSteps,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  // Factory to create from AI response
   factory TaskHiveModel.fromAIMap(Map<String, dynamic> map, TaskLevelName level, String? parentId, int taskOrder, String? goalId) {
    return TaskHiveModel(
      id:  _uuid.v4(),
      taskLevel: level,
      parentTaskId: parentId,
      title: map['title'] as String? ?? 'Untitled Task',
      purpose: map['purpose'] as String?,
      duration: map['estimated_duration'] as String? ?? 'N/A',
      order: taskOrder,
      goalId: goalId,
      subSteps: map.containsKey('sub_steps')
          ? (map['sub_steps'] as List<dynamic>)
              .map((step) => {'text': step.toString(), 'isDone': false})
              .toList()
          : null,
    );
  }
}