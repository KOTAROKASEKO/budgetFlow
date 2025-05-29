import 'package:hive/hive.dart';

part 'userSettingsModel.g.dart'; // Will be generated

@HiveType(typeId: 1) // Ensure typeId is unique (0 is used by expenseModel)
class UserSettingsModel extends HiveObject {
  @HiveField(0)
  int budget;

  @HiveField(1)
  String? themePreference; // Example of another setting

  // You might want to associate settings with a user if not using userId as the primary key for the box entry
  // @HiveField(2)
  // String userId;

  UserSettingsModel({
    required this.budget,
    this.themePreference,
    // required this.userId,
  });
}