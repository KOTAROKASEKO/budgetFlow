// dashboard/database/dasboardDB.dart
import 'package:hive/hive.dart';
import 'package:moneymanager/Transaction_Views/buyLlist/model/buy_list_item_model.dart';
import 'package:moneymanager/Transaction_Views/dashboard/model/expenseModel.dart'; // Assuming this is the correct path
import 'package:moneymanager/Transaction_Views/dashboard/model/userSettingsModel.dart';
import 'package:moneymanager/Transaction_Views/setting.dart'; // Assuming this is the correct path

class dashBoardDBManager {
  static const String buyListItemsBoxName = 'buyListItemsBox';
  static const String expenseCacheBoxName = 'monthlyExpensesCache'; // Already defined in DashBoard.dart
  static const String _userSettingsBoxName = 'userSettings'; // Already defined in DashBoard.dart
  static const String currencySettingBoxName = SettingRepository.boxName;

  static Future<void> init() async {
    print("[DBManager] init() called.");

    // --- Register expenseModelAdapter (typeId 5) ---
    try {
      Hive.registerAdapter(expenseModelAdapter());
      print("[DBManager] expenseModelAdapter registration call made.");
    } on HiveError catch (e) {
      if (e.message.contains("already registered")) {
        print("[DBManager] expenseModelAdapter was already registered.");
      } else {
        print("[DBManager] HiveError during expenseModelAdapter registration: $e");
        rethrow;
      }
    } catch (e) {
      print("[DBManager] Unexpected error during expenseModelAdapter registration: $e");
      rethrow;
    }

    // --- Register UserSettingsModelAdapter (typeId 6) ---
    final userSettingsAdapter = UserSettingsModelAdapter();
    try {
      Hive.registerAdapter(userSettingsAdapter);
      print("[DBManager] UserSettingsModelAdapter registration call made (typeId: ${userSettingsAdapter.typeId}).");
    } on HiveError catch (e) {
      if (e.message.contains("already registered")) {
        print("[DBManager] UserSettingsModelAdapter (typeId: ${userSettingsAdapter.typeId}) was already registered.");
      } else {
        print("[DBManager] HiveError during UserSettingsModelAdapter registration: $e");
        rethrow;
      }
    } catch (e) {
      print("[DBManager] Unexpected error during UserSettingsModelAdapter registration: $e");
      rethrow;
    }

    // --- Register BuyListItemAdapter (typeId 7) ---
    final buyListItemAdapter = BuyListItemAdapter();
    try {
      Hive.registerAdapter(buyListItemAdapter);
      print("[DBManager] BuyListItemAdapter registration call made (typeId: ${buyListItemAdapter.typeId}).");
    } on HiveError catch (e) {
      if (e.message.contains("already registered")) {
        print("[DBManager] BuyListItemAdapter (typeId: ${buyListItemAdapter.typeId}) was already registered.");
      } else {
        print("[DBManager] HiveError during BuyListItemAdapter registration: $e");
        rethrow;
      }
    } catch (e) {
      print("[DBManager] Unexpected error during BuyListItemAdapter registration: $e");
      rethrow;
    }


    // --- Open Boxes ---
    if (!Hive.isBoxOpen(expenseCacheBoxName)) {
      await Hive.openBox<List<dynamic>>(expenseCacheBoxName);
      print("[DBManager] Box '$expenseCacheBoxName' opened.");
    } else {
      print("[DBManager] Box '$expenseCacheBoxName' was already open.");
    }

    if (!Hive.isBoxOpen(_userSettingsBoxName)) {
      await Hive.openBox(_userSettingsBoxName);
      print("[DBManager] Box '$_userSettingsBoxName' opened.");
    } else {
      print("[DBManager] Box '$_userSettingsBoxName' was already open.");
    }

    if (!Hive.isBoxOpen(buyListItemsBoxName)) {
      await Hive.openBox<BuyListItem>(buyListItemsBoxName);
      print("[DBManager] Box '$buyListItemsBoxName' opened.");
    } else {
      print("[DBManager] Box '$buyListItemsBoxName' was already open.");
    }

     if (!Hive.isBoxOpen(currencySettingBoxName)) {
      await Hive.openBox(currencySettingBoxName);
      print("[DBManager] Box '$currencySettingBoxName' opened.");
    } else {
      print("[DBManager] Box '$currencySettingBoxName' was already open.");
    }

    
    print("[DBManager] init() finished.");
  }
}