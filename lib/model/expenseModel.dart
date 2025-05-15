import 'package:flutter/material.dart';

class expenseModel {
  double amount;
  int date;
  String id;
  String? description;
  String? category;
  String? type;
  expenseModel(
      {required this.amount,
      required this.date,
      required this.id,
      required this.description,
      required this.category,
      required this.type
      });
}

//===============================================================//
//                       TILE PROPERTY                           //
//===============================================================//

class ExpenseTypeModel {
  Widget itemIcon;
  String itemName;

  ExpenseTypeModel({required this.itemIcon, required this.itemName});
}

