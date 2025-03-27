import 'package:flutter/material.dart';

class expenseModel{
    double amount;
    int date;
    String id;
    String? description;
    String? category;
    expenseModel({required this.amount, required this.date, required this.id, required this.description, required this.category});
}

//===============================================================//
//                       TILE PROPERTY                           //
//===============================================================//

class categoryStorage{
  static List<String> categoryList = [
    "Food", 
    "Transport", 
    "Entertainment", 
    "Others",
    ];

  static List<MaterialColor> colorList = [
    Colors.red,//food
    Colors.blue,//transport
    Colors.green,//entertainment
    Colors.cyan,//others
  ]; 
}


