// DashBoard_MapTask/NoteView.dart
import 'package:flutter/material.dart';
import 'package:moneymanager/aisupport/DashBoard_MapTask/notes/note_veiwmodel.dart';
import 'package:moneymanager/themeColor.dart';

/// A self-contained screen for creating and editing a daily note.
class NoteEditorScreen extends StatefulWidget {
  final NoteViewModel noteViewModel;
  final DateTime day;
  final String goalId;
  final String? initialContent;
  final String? noteId; // To identify the note being edited

  const NoteEditorScreen({
    super.key,
    required this.noteViewModel,
    required this.day,
    required this.goalId,
    this.initialContent,
    this.noteId, // Add to constructor
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    // Initialize the controller with any existing text.
    _noteController = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _saveAndExit() {
    widget.noteViewModel.saveNote(
      content: _noteController.text,
      day: widget.day,
      goalId: widget.goalId,
      noteId: widget.noteId, // Pass the noteId
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // This build method creates the entire note screen, not a modal.
    return Scaffold(
      backgroundColor: theme.apptheme_Black,
      appBar: AppBar(
        title: Text('Note for ${widget.day.month}/${widget.day.day}',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: theme.apptheme_Black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: "Save Note",
            onPressed: _saveAndExit,
          ),
        ],
      ),
      body: ListView(
        children: [
          TextField(
            controller: _noteController,
            autofocus: true,
            maxLines: null, // Allow infinite lines
            minLines: 15, // Make the text field larger
            style: const TextStyle(
                color: Color.fromARGB(255, 255, 255, 255), fontSize: 18),
            decoration: const InputDecoration(
              fillColor: Colors.black,
              hintText: "Your note for the day...",
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}