import 'package:hive_flutter/hive_flutter.dart';
import 'package:moneymanager/aisupport/Database/user_plan_hive.dart';
import 'package:moneymanager/aisupport/models/phase_hive.dart';
import 'package:moneymanager/aisupport/models/monthly_task_hive.dart';
import 'package:moneymanager/aisupport/models/weekly_task_hive.dart';
import 'package:moneymanager/aisupport/models/daily_task_hive.dart';

class LocalDatabaseService {
  static const String userPlansBoxName = 'userFinancialPlans';

  Future<void> init() async {
    

    // Register Adapters
    if (!Hive.isAdapterRegistered(UserPlanHiveAdapter().typeId)) {
      Hive.registerAdapter(UserPlanHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(PhaseHiveAdapter().typeId)) {
      Hive.registerAdapter(PhaseHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(MonthlyTaskHiveAdapter().typeId)) {
      Hive.registerAdapter(MonthlyTaskHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(WeeklyTaskHiveAdapter().typeId)) {
      Hive.registerAdapter(WeeklyTaskHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(DailyTaskHiveAdapter().typeId)) {
      Hive.registerAdapter(DailyTaskHiveAdapter());
    } 
    await Hive.openBox<UserPlanHive>(userPlansBoxName);
  }

  Box<UserPlanHive> get _userPlansBox => Hive.box<UserPlanHive>(userPlansBoxName);

  // Save or Update a UserPlan
  Future<void> saveUserPlan(UserPlanHive plan) async {
    // Hive uses the key to store objects. If you use `put(key, value)`,
    // the `goalName` can be the key.
    await _userPlansBox.put(plan.goalName, plan);
    print("Plan '${plan.goalName}' saved to Hive.");
  }

  // Get a UserPlan by goalName
  UserPlanHive? getUserPlan(String goalName) {
    return _userPlansBox.get(goalName);
  }

  // Get all UserPlan names (similar to goalCollectionNames)
  List<String> getAllGoalNames() {
    return _userPlansBox.keys.cast<String>().toList();
  }

  // Get all UserPlans
  List<UserPlanHive> getAllUserPlans() {
    return _userPlansBox.values.toList();
  }


  // Delete a UserPlan
  Future<void> deleteUserPlan(String goalName) async {
    await _userPlansBox.delete(goalName);
  }

  // Check if a plan exists
  bool checkPlanExists(String goalName) {
    return _userPlansBox.containsKey(goalName);
  }

  Future<void> close() async {
    await Hive.close();
  }
}