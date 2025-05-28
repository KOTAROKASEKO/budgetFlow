import 'package:hive/hive.dart';
import 'daily_task_hive.dart';

part 'weekly_task_hive.g.dart';

@HiveType(typeId: 3)
class WeeklyTaskHive extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String estimatedDuration;

  @HiveField(3)
  String purpose;

  @HiveField(4)
  int order;

  @HiveField(5)
  List<DailyTaskHive> dailyTasks;

  WeeklyTaskHive({
    required this.id,
    required this.title,
    required this.estimatedDuration,
    required this.purpose,
    required this.order,
    required this.dailyTasks,
  });
}