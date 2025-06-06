// File: lib/aisupport/viewmodel/goal_input_viewmodel.dart
import 'package:flutter/foundation.dart';

class GoalInputViewModel extends ChangeNotifier {
  String earnThisYear = '';
  String duration = ''; // e.g. "2 years", "6 months"
  String currentSkill = '';
  String preferToEarnMoney = '';
  String note = '';

  bool validateInputs() {
    return earnThisYear.isNotEmpty &&
           duration.isNotEmpty &&
           currentSkill.isNotEmpty;
  }
}