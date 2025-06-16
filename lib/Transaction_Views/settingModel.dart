library settingModel;

import 'package:hive/hive.dart';

part 'settingModel.g.dart'; // Will be generated

@HiveType(typeId: 14) // Ensure typeId is unique (0 is used by expenseModel)
class UserSettingsModel extends HiveObject {
  @HiveField(0)
  int budget;

  @HiveField(1)
  String? themePreference; // Example of another setting

  @HiveField(2)
  String? currency;

  UserSettingsModel({
    required this.budget,
    this.themePreference,
    this.currency,
  });
}