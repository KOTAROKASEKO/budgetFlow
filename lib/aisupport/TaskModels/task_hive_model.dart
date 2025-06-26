// lib/aisupport/models/task_hive_model.dart
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'task_hive_model.g.dart';

var _uuid = Uuid();

@HiveType(typeId: 10)
enum TaskLevelName {
  @HiveField(0)
  Goal,
  @HiveField(1)
  Phase,
  @HiveField(2)
  Milestone,
  @HiveField(3)
  Daily,
}

@HiveType(typeId: 11)
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
  String duration;

  @HiveField(6)
  bool isDone;

  @HiveField(7)
  int order;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime? dueDate;

  @HiveField(10)
  String? status;

  @HiveField(11)
  String? userInputEarnTarget;

  @HiveField(12)
  String? userInputDuration;

  @HiveField(13)
  String? userInputCurrentSkill;

  @HiveField(14)
  String? userInputPreferToEarnMoney;

  @HiveField(15)
  String? userInputNote;

  @HiveField(16)
  String? goalId;

  @HiveField(17)
  DateTime? notificationTime;

  @HiveField(18)
  List<Map<String, dynamic>>? subSteps;
  
  @HiveField(19)
  List<Map<String, dynamic>>? definitionOfDone;

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
    this.definitionOfDone,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  factory TaskHiveModel.fromAIMap(Map<String, dynamic> map, TaskLevelName level, String? parentId, int taskOrder, String? goalId) {
    return TaskHiveModel(
      id:  _uuid.v4(),
      taskLevel: level,
      parentTaskId: parentId,
      title: map['title'] as String? ?? 'Untitled Task',
      purpose: map['purpose'] as String?,
      duration: level == TaskLevelName.Daily ? '1 day' : 'N/A',
      order: taskOrder,
      goalId: goalId,
      subSteps: map.containsKey('sub_steps')
          ? (map['sub_steps'] as List<dynamic>)
              .map((step) => {'text': step.toString(), 'isDone': false})
              .toList()
          : null,
      // NEW: Parse definition_of_done for Milestones
      definitionOfDone: map.containsKey('definition_of_done')
          ? (map['definition_of_done'] as List<dynamic>)
              .map((item) => {'text': item.toString(), 'isDone': false})
              .toList()
          : null,
    );
  }
}