import 'package:flutter/material.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/notes/model/note_hive_model.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/notes/note_repository.dart';

class NoteViewModel extends ChangeNotifier {
  final NoteRepository _noteRepository;
  NoteHiveModel? _noteForSelectedDay;
  bool _isLoading = false;

  NoteViewModel({required NoteRepository noteRepository})
      : _noteRepository = noteRepository;

  NoteHiveModel? get noteForSelectedDay => _noteForSelectedDay;
  bool get isLoading => _isLoading;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> loadNoteForDay(DateTime day, String goalId) async {
    _setLoading(true);
    _noteForSelectedDay = await _noteRepository.getNoteForDay(day, goalId);
    _setLoading(false);
  }

  Future<void> saveNote(
      String content, DateTime day, String goalId) async {
    if (content.trim().isEmpty) {
      // If content is empty, delete existing note if it exists
      if (_noteForSelectedDay != null) {
        await _noteRepository.deleteNote(_noteForSelectedDay!.id);
        _noteForSelectedDay = null;
      }
    } else {
      // If content is not empty, create or update note
      final noteToSave = NoteHiveModel(
        id: _noteForSelectedDay?.id, // Keep ID for updates
        content: content,
        date: day,
        goalId: goalId,
      );
      await _noteRepository.saveNote(noteToSave);
      _noteForSelectedDay = noteToSave;
    }
    notifyListeners();
  }
}