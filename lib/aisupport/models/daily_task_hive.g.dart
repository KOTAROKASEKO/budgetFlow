// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_task_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyTaskHiveAdapter extends TypeAdapter<DailyTaskHive> {
  @override
  final int typeId = 4;

  @override
  DailyTaskHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyTaskHive(
      id: fields[0] as String,
      title: fields[1] as String,
      purpose: fields[2] as String?,
      estimatedDuration: fields[3] as String?,
      dueDate: fields[4] as DateTime,
      status: fields[5] as String,
      order: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DailyTaskHive obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.purpose)
      ..writeByte(3)
      ..write(obj.estimatedDuration)
      ..writeByte(4)
      ..write(obj.dueDate)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.order);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyTaskHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
