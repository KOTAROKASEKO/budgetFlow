import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'note_hive_model.g.dart';

var _uuid = Uuid();

@HiveType(typeId: 12) // New unique typeId
class NoteHiveModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  String content;

  @HiveField(3)
  String goalId; // To associate the note with a specific goal

  NoteHiveModel({
    String? id,
    required this.date,
    required this.content,
    required this.goalId,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'content': content,
      'goalId': goalId,
    };
  }

  static fromJson(Map<String, dynamic> map) {}
}