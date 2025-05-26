import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class expenseModel {
  double amount;
  int date;
  String id;
  String? description;
  String? category;
  String? type;
  Timestamp? timestamp;
  expenseModel(
      {required this.amount,
      required this.date,
      required this.id,
      required this.description,
      required this.category,
      required this.type,
      required this.timestamp
      });
        factory expenseModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return expenseModel(
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      date: (data['date'] as num?)?.toInt() ?? DateTime.fromMillisecondsSinceEpoch((data['timestamp'] as Timestamp).millisecondsSinceEpoch).day,
      id: doc.id,
      description: data['description'] as String?,
      category: data['category'] as String?,
      type: data['type'] as String?,
      timestamp: data['timestamp'] as Timestamp, // Ensure this is correctly fetched
    );
  }
}

//===============================================================//
//                       TILE PROPERTY                           //
//===============================================================//

class ExpenseTypeModel {
  Widget itemIcon;
  String itemName;

  ExpenseTypeModel({required this.itemIcon, required this.itemName});
}

