import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:moneymanager/security/uid.dart';

class Setting extends ChangeNotifier{
  final SettingRepository repo = SettingRepository();
  late String currency; // `late`を使い、後で初期化されることを示す
  bool isLoading = true;

  Setting() {
    loadCurrency();
  }

  // 初期化時に通貨を読み込む
  void loadCurrency() {
    currency = repo.getCurrency();
    isLoading = false;
    // コンストラクタ内なので、最初のビルドで値が反映されるため
    // ここでnotifyListeners()を呼ぶ必要はありません。
  }

  Future<void> setCurrency(String newCurrency) async {
    currency = newCurrency;
    repo.saveCurrency(newCurrency);
    notifyListeners();
  }
}

class SettingRepository {
  // 外部からボックス名を参照できるようにstatic constにするのがおすすめです
  static const String boxName = 'currencySetting';

  void saveCurrency(String newCurrency) {
    // このメソッドを呼ぶ前に 'currencySetting' ボックスが開かれている必要があります
    final settingsBox = Hive.box(boxName);
    final key = '${userId.uid}_currency';
    settingsBox.put(key, newCurrency);
  }

  String getCurrency() {
    // このメソッドを呼ぶ前に 'currencySetting' ボックスが開かれている必要があります
    final settingsBox = Hive.box(boxName);
    final key = '${userId.uid}_currency';
    return settingsBox.get(key, defaultValue: 'RM');
  }
}