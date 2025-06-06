// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskHiveModelAdapter extends TypeAdapter<TaskHiveModel> {
  @override
  final int typeId = 11;

  @override
  TaskHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskHiveModel(
      id: fields[0] as String?,
      taskLevel: fields[1] as TaskLevelName,
      parentTaskId: fields[2] as String?,
      title: fields[3] as String,
      purpose: fields[4] as String?,
      duration: fields[5] as String,
      isDone: fields[6] as bool,
      order: fields[7] as int,
      createdAt: fields[8] as DateTime?,
      dueDate: fields[9] as DateTime?,
      status: fields[10] as String?,
      userInputEarnTarget: fields[11] as String?,
      userInputDuration: fields[12] as String?,
      userInputCurrentSkill: fields[13] as String?,
      userInputPreferToEarnMoney: fields[14] as String?,
      userInputNote: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TaskHiveModel obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.taskLevel)
      ..writeByte(2)
      ..write(obj.parentTaskId)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.purpose)
      ..writeByte(5)
      ..write(obj.duration)
      ..writeByte(6)
      ..write(obj.isDone)
      ..writeByte(7)
      ..write(obj.order)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.dueDate)
      ..writeByte(10)
      ..write(obj.status)
      ..writeByte(11)
      ..write(obj.userInputEarnTarget)
      ..writeByte(12)
      ..write(obj.userInputDuration)
      ..writeByte(13)
      ..write(obj.userInputCurrentSkill)
      ..writeByte(14)
      ..write(obj.userInputPreferToEarnMoney)
      ..writeByte(15)
      ..write(obj.userInputNote);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaskLevelNameAdapter extends TypeAdapter<TaskLevelName> {
  @override
  final int typeId = 10;

  @override
  TaskLevelName read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TaskLevelName.Goal;
      case 1:
        return TaskLevelName.Phase;
      case 2:
        return TaskLevelName.Monthly;
      case 3:
        return TaskLevelName.Weekly;
      case 4:
        return TaskLevelName.Daily;
      default:
        return TaskLevelName.Goal;
    }
  }

  @override
  void write(BinaryWriter writer, TaskLevelName obj) {
    switch (obj) {
      case TaskLevelName.Goal:
        writer.writeByte(0);
        break;
      case TaskLevelName.Phase:
        writer.writeByte(1);
        break;
      case TaskLevelName.Monthly:
        writer.writeByte(2);
        break;
      case TaskLevelName.Weekly:
        writer.writeByte(3);
        break;
      case TaskLevelName.Daily:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskLevelNameAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
