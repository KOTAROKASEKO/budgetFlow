import 'package:hive/hive.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/notes/model/note_hive_model.dart';


class NoteRepository {
  static const String _boxName = 'aiUserNotes_v1';

  Future<Box<NoteHiveModel>> _getBox() async {
    if (!Hive.isAdapterRegistered(NoteHiveModelAdapter().typeId)) {
      Hive.registerAdapter(NoteHiveModelAdapter());
    }
    return await Hive.openBox<NoteHiveModel>(_boxName);
  }

  Future<void> saveNote(NoteHiveModel note) async {
    final box = await _getBox();
    await box.put(note.id, note);
  }

  Future<NoteHiveModel?> getNoteForDay(DateTime date, String goalId) async {
    final box = await _getBox();
    final normalizedDate = DateTime.utc(date.year, date.month, date.day);
    try {
      return box.values.firstWhere((note) =>
          note.goalId == goalId &&
          note.date.year == normalizedDate.year &&
          note.date.month == normalizedDate.month &&
          note.date.day == normalizedDate.day);
    } catch (e) {
      return null; // Not found
    }
  }

  Future<void> deleteNote(String noteId) async {
    final box = await _getBox();
    await box.delete(noteId);
  }
}