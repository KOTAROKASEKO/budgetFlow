// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'buy_list_item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BuyListItemAdapter extends TypeAdapter<BuyListItem> {
  @override
  final int typeId = 7;

  @override
  BuyListItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BuyListItem(
      id: fields[0] as String,
      itemName: fields[1] as String,
      price: fields[2] as double,
      createdAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, BuyListItem obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.itemName)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuyListItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
