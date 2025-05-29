// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expenseModel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class expenseModelAdapter extends TypeAdapter<expenseModel> {
  @override
  final int typeId = 0;

  @override
  expenseModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return expenseModel(
      amount: fields[0] as double,
      date: fields[1] as int,
      id: fields[2] as String,
      description: fields[3] as String?,
      category: fields[4] as String?,
      type: fields[5] as String?,
      timestamp: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, expenseModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.amount)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.id)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is expenseModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
