// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_plan_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserPlanHiveAdapter extends TypeAdapter<UserPlanHive> {
  @override
  final int typeId = 0;

  @override
  UserPlanHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserPlanHive(
      goalName: fields[0] as String,
      earnThisYear: fields[1] as String,
      currentSkill: fields[2] as String,
      preferToEarnMoney: fields[3] as String,
      note: fields[4] as String,
      phases: (fields[5] as List).cast<PhaseHive>(),
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, UserPlanHive obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.goalName)
      ..writeByte(1)
      ..write(obj.earnThisYear)
      ..writeByte(2)
      ..write(obj.currentSkill)
      ..writeByte(3)
      ..write(obj.preferToEarnMoney)
      ..writeByte(4)
      ..write(obj.note)
      ..writeByte(5)
      ..write(obj.phases)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPlanHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
