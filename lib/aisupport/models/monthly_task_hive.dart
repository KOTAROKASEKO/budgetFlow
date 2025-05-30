import 'package:hive/hive.dart';
import 'weekly_task_hive.dart'; // Assuming weekly tasks break down from monthly

part 'monthly_task_hive.g.dart';

@HiveType(typeId: 2)
class MonthlyTaskHive extends HiveObject {
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
  List<WeeklyTaskHive> weeklyTasks; // Or daily tasks if structure is flatter

  MonthlyTaskHive({
    required this.id,
    required this.title,
    required this.estimatedDuration,
    required this.purpose,
    required this.order,
    required this.weeklyTasks,
  });
}