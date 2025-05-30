import 'package:hive/hive.dart';

part 'daily_task_hive.g.dart';

@HiveType(typeId: 4)
class DailyTaskHive extends HiveObject {
  @HiveField(0)
  String id; // Corresponds to taskId

  @HiveField(1)
  String title; // Corresponds to taskName

  @HiveField(2)
  String? purpose; // From AI generation

  @HiveField(3)
  String? estimatedDuration; // From AI generation

  @HiveField(4)
  DateTime dueDate;

  @HiveField(5)
  String status; // e.g., 'pending', 'in-progress', 'completed'

  @HiveField(6)
  int order;

  DailyTaskHive({
    required this.id,
    required this.title,
    this.purpose,
    this.estimatedDuration,
    required this.dueDate,
    this.status = 'pending',
    required this.order,
  });
}