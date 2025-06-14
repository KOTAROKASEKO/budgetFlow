// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'streak_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StreakHiveModelAdapter extends TypeAdapter<StreakHiveModel> {
  @override
  final int typeId = 13;

  @override
  StreakHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StreakHiveModel(
      id: fields[0] as String,
      currentStreak: fields[1] as int,
      lastCompletionDate: fields[2] as DateTime?,
      totalPoints: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, StreakHiveModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.currentStreak)
      ..writeByte(2)
      ..write(obj.lastCompletionDate)
      ..writeByte(3)
      ..write(obj.totalPoints);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
