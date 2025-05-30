// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weekly_task_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WeeklyTaskHiveAdapter extends TypeAdapter<WeeklyTaskHive> {
  @override
  final int typeId = 3;

  @override
  WeeklyTaskHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeeklyTaskHive(
      id: fields[0] as String,
      title: fields[1] as String,
      estimatedDuration: fields[2] as String,
      purpose: fields[3] as String,
      order: fields[4] as int,
      dailyTasks: (fields[5] as List).cast<DailyTaskHive>(),
    );
  }

  @override
  void write(BinaryWriter writer, WeeklyTaskHive obj) {
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
      ..write(obj.dailyTasks);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklyTaskHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
