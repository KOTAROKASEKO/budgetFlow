import 'package:flutter/material.dart';

class expenseModel {
  double amount;
  int date;
  String id;
  String? description;
  String? category;
  expenseModel(
      {required this.amount,
      required this.date,
      required this.id,
      required this.description,
      required this.category});
}

//===============================================================//
//                       TILE PROPERTY                           //
//===============================================================//

class ExpenseTypeModel {
  Widget itemIcon;
  String itemName;

  ExpenseTypeModel({required this.itemIcon, required this.itemName});
}

class expenseInstances {
  List<ExpenseTypeModel> icons = [
    ExpenseTypeModel(
      itemIcon: getIcon(Icons.fastfood, const Color.fromARGB(255, 255, 102, 0)), // アイコン修正
      itemName: "Food",),
    ExpenseTypeModel(
      itemIcon: getIcon(Icons.directions_bus, Colors.blue), // アイコン修正
      itemName: "Transport",),
    ExpenseTypeModel(
      itemIcon: getIcon(Icons.local_movies, Colors.red), // アイコン修正
      itemName: "Entertainment",),
    ExpenseTypeModel(
        itemIcon: getIcon(
            Icons.phone_android, const Color.fromARGB(255, 34, 255, 0)),
        itemName: 'Online'),
    ExpenseTypeModel(
        itemIcon: getIcon(Icons.settings_input_component_sharp, const Color.fromARGB(255, 34, 255, 0)),
        itemName: 'Investment'),
    ExpenseTypeModel(
      itemIcon: getIcon(Icons.shopping_cart, const Color.fromARGB(255, 255, 102, 0)), // アイコン修正
      itemName: "Shopping",),
    ExpenseTypeModel(
        itemIcon: getIcon(Icons.medical_information, Colors.blue),
        itemName: 'Medical'),
    ExpenseTypeModel(
        itemIcon: getIcon(Icons.construction, Colors.red), 
        itemName: 'Gadget'),
    ExpenseTypeModel(
      itemIcon: getIcon(Icons.more_horiz, Colors.red), // アイコン修正
      itemName: "Others",),
    ExpenseTypeModel(
        itemIcon: getIcon(Icons.card_giftcard_outlined, const Color.fromARGB(255, 34, 255, 0)),
        itemName: 'Gift'),
  ];

  static Widget getIcon(IconData selectedIcon, Color selectedColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: selectedColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 3), // 影の位置調整
          ),
        ],
      ),
      child: Center(
        child: Icon(selectedIcon, color: Colors.white),
      ),
    );
  }
}
