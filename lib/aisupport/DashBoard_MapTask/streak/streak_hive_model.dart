// lib/aisupport/DashBoard_MapTask/streak/streak_hive_model.dart
import 'package:hive/hive.dart';
import 'package:moneymanager/security/uid.dart';

part 'streak_hive_model.g.dart';

@HiveType(typeId: 13) // Ensure this typeId is unique
class StreakHiveModel extends HiveObject {
  // Use a constant key for the singleton user streak object
  static const String streakKey = 'userStreak';

  @HiveField(0)
  String id;

  @HiveField(1)
  int currentStreak;

  @HiveField(2)
  DateTime? lastCompletionDate;

  @HiveField(3)
  int totalPoints;

  StreakHiveModel({
    required this.id,
    this.currentStreak = 0,
    this.lastCompletionDate,
    this.totalPoints = 0,
  });

  // Factory to create a default instance for the current user
  factory StreakHiveModel.initial() {
    return StreakHiveModel(
      id: userId.uid,
      currentStreak: 0,
      totalPoints: 0,
      lastCompletionDate: null,
    );
  }

  Map<String, dynamic> toJson(StreakHiveModel model ) {
    return {
      'streakCount': model.currentStreak,
      'lastUpdated': model.lastCompletionDate!.toIso8601String(),
      'totalPoint': model.totalPoints,
    };
  }
}