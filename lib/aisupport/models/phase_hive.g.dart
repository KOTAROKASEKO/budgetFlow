// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'phase_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PhaseHiveAdapter extends TypeAdapter<PhaseHive> {
  @override
  final int typeId = 1;

  @override
  PhaseHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PhaseHive(
      id: fields[0] as String,
      title: fields[1] as String,
      estimatedDuration: fields[2] as String,
      purpose: fields[3] as String,
      order: fields[4] as int,
      monthlyTasks: (fields[5] as List).cast<MonthlyTaskHive>(),
    );
  }

  @override
  void write(BinaryWriter writer, PhaseHive obj) {
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
      ..write(obj.monthlyTasks);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhaseHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
