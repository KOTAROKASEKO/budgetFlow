import 'package:hive/hive.dart';
import 'monthly_task_hive.dart';

part 'phase_hive.g.dart';

@HiveType(typeId: 1)
class PhaseHive extends HiveObject {
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
  List<MonthlyTaskHive> monthlyTasks;

  PhaseHive({
    required this.id,
    required this.title,
    required this.estimatedDuration,
    required this.purpose,
    required this.order,
    required this.monthlyTasks,
  });
}