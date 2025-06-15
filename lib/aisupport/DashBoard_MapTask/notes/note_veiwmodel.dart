// aisupport/DashBoard_MapTask/notes/note_veiwmodel.dart

import 'package:flutter/material.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/notes/model/note_hive_model.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/notes/note_repository.dart';

class NoteViewModel extends ChangeNotifier {
  final NoteRepository _noteRepository;
  List<NoteHiveModel> _notesForSelectedDay = [];
  bool _isLoading = false;

  NoteViewModel({required NoteRepository noteRepository})
      : _noteRepository = noteRepository;

  List<NoteHiveModel> get notesForSelectedDay => _notesForSelectedDay;
  bool get isLoading => _isLoading;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> loadNoteForDay(DateTime day, String goalId) async {
    _setLoading(true);
    _notesForSelectedDay = await _noteRepository.getNotesForDay(
      goalId: goalId,
      year: day.year,
      month: day.month,
      day: day.day,
    );
    _setLoading(false);
  }

  Future<void> saveNote({
    required String content,
    required DateTime day,
    required String goalId,
    String? noteId,
  }) async {
    // If the content is empty for an existing note, delete it.
    if (content.trim().isEmpty && noteId != null) {
      await deleteNote(noteId: noteId, day: day, goalId: goalId);
      return;
    }
    // Do not save new empty notes.
    if (content.trim().isEmpty) return;

    // Create a new note object. The constructor will generate a new ID if `noteId` is null.
    final noteToSave = NoteHiveModel(
      id: noteId,
      content: content,
      date: day,
      goalId: goalId,
    );
    await _noteRepository.saveNote(noteToSave);
    await loadNoteForDay(day, goalId); // Refresh the list from storage
  }

  Future<void> deleteNote({
    required String noteId,
    required DateTime day,
    required String goalId,
  }) async {
    await _noteRepository.deleteNote(noteId);
    await loadNoteForDay(day, goalId); // Refresh the list
  }

  /// Clears the currently displayed notes.
  void clearCurrentNote() {
    _notesForSelectedDay = [];
    notifyListeners();
  }
}