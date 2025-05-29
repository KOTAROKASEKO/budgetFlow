import 'package:hive/hive.dart';
import 'package:moneymanager/dashboard/model/expenseModel.dart';
import 'package:moneymanager/dashboard/model/userSettingsModel.dart';

class dashBoardDBManager{
  Future<void > init() async {
    if (!Hive.isAdapterRegistered(expenseModelAdapter().typeId)) {
      Hive.registerAdapter(expenseModelAdapter());
    }
    if (!Hive.isAdapterRegistered(UserSettingsModelAdapter().typeId)) {
      Hive.registerAdapter(UserSettingsModelAdapter());
    } 
    await Hive.openBox<expenseModel>('expenseModelBox');
    await Hive.openBox<UserSettingsModel>('userSettingsModelBox');
  }       
}