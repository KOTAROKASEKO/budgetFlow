// lib/models/buy_list_item_model.dart
import 'package:hive/hive.dart';

part 'buy_list_item_model.g.dart'; // This will be generated

@HiveType(typeId: 7) // Ensure this typeId is unique
class BuyListItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String itemName;

  @HiveField(2)
  double price;

  @HiveField(3)
  DateTime createdAt;

  BuyListItem({
    required this.id,
    required this.itemName,
    required this.price,
    required this.createdAt,
  });
}