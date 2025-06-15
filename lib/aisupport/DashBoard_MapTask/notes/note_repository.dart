import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/notes/model/note_hive_model.dart';
import 'package:moneymanager/security/uid.dart';


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
    FirebaseFirestore.instance.collection('note').doc(userId.uid).set(note.toJson());
  }

  Future<List<NoteHiveModel>> getNotesForDay({
    required String goalId,
    required int year,
    required int month,
    required int day,
  }) async {
    final box = await _getBox();
    if (box.isNotEmpty) {
      return box.values.where((note) =>
        note.goalId == goalId &&
        note.date.year == year &&
        note.date.month == month &&
        note.date.day == day
      ).toList();
    } else {
      // Fetch from Firestore if local box is empty
      final querySnapshot = await FirebaseFirestore.instance
          .collection('note')
          .doc(userId.uid)
          .collection('notes')
          .get();

      List<NoteHiveModel> notes = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        try {
          final note = NoteHiveModel.fromJson(data);
          // Save to Hive for caching
          await box.put(note.id, note);
          // Filter by date and goalId
          if (note.goalId == goalId &&
              note.date.year == year &&
              note.date.month == month &&
              note.date.day == day) {
            notes.add(note);
          }
        } catch (_) {
          // Handle or log error if needed
        }
      }
      return notes;
    }
  }

  Future<void> deleteNote(String noteId) async {
    final box = await _getBox();
    await box.delete(noteId);
  }
}