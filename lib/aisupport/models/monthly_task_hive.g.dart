// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monthly_task_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MonthlyTaskHiveAdapter extends TypeAdapter<MonthlyTaskHive> {
  @override
  final int typeId = 2;

  @override
  MonthlyTaskHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MonthlyTaskHive(
      id: fields[0] as String,
      title: fields[1] as String,
      estimatedDuration: fields[2] as String,
      purpose: fields[3] as String,
      order: fields[4] as int,
      weeklyTasks: (fields[5] as List).cast<WeeklyTaskHive>(),
    );
  }

  @override
  void write(BinaryWriter writer, MonthlyTaskHive obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.estimatedDuration)
      ..writeByte(3)
      ..write(obj.purpose)
      ..writeByte(4)
      ..write(obj.order)
      ..writeByte(5)
      ..write(obj.weeklyTasks);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyTaskHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
