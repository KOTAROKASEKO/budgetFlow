import 'package:hive/hive.dart';
import 'package:moneymanager/Transaction_Views/dashboard/model/expenseModel.dart';
import 'package:moneymanager/Transaction_Views/dashboard/model/userSettingsModel.dart';

class dashBoardDBManager {
  static Future<void> init() async {
    print("[DBManager] init() called.");

    // --- Register expenseModelAdapter (typeId 0) ---
    try {
      // Attempt to register unconditionally
      Hive.registerAdapter(expenseModelAdapter());
      print("[DBManager] expenseModelAdapter registration call made.");
    } on HiveError catch (e) {
      if (e.message.contains("already registered")) {
        print("[DBManager] expenseModelAdapter was already registered (caught HiveError).");
      } else {
        print("[DBManager] HiveError during expenseModelAdapter registration: $e");
        rethrow; // Rethrow other HiveErrors
      }
    } catch (e) {
      print("[DBManager] Unexpected error during expenseModelAdapter registration: $e");
      rethrow; // Rethrow unexpected errors
    }

    // --- Register UserSettingsModelAdapter (typeId 1) ---
    // Ensure UserSettingsModelAdapter is correctly generated and accessible
    final userSettingsAdapter = UserSettingsModelAdapter();
    // ignore: unnecessary_null_comparison
    if (userSettingsAdapter.typeId != null) { // typeId for UserSettingsModel is 1
      try {
        Hive.registerAdapter(userSettingsAdapter);
        print("[DBManager] UserSettingsModelAdapter registration call made (typeId: ${userSettingsAdapter.typeId}).");
      } on HiveError catch (e) {
        if (e.message.contains("already registered")) {
          print("[DBManager] UserSettingsModelAdapter (typeId: ${userSettingsAdapter.typeId}) was already registered (caught HiveError).");
        } else {
          print("[DBManager] HiveError during UserSettingsModelAdapter registration: $e");
          rethrow;
        }
      } catch (e) {
        print("[DBManager] Unexpected error during UserSettingsModelAdapter registration: $e");
        rethrow;
      }
    } else {
      print("[DBManager] UserSettingsModelAdapter.typeId is null. Skipping registration.");
    }

    // --- Open Boxes ---
    if (!Hive.isBoxOpen('monthlyExpensesCache')) {
      await Hive.openBox<List<dynamic>>('monthlyExpensesCache');
      print("[DBManager] Box 'monthlyExpensesCache' opened.");
    } else {
      print("[DBManager] Box 'monthlyExpensesCache' was already open.");
    }

    if (!Hive.isBoxOpen('userSettings')) {
      await Hive.openBox('userSettings');
      print("[DBManager] Box 'userSettings' opened.");
    } else {
      print("[DBManager] Box 'userSettings' was already open.");
    }
    print("[DBManager] init() finished.");
  }
} 