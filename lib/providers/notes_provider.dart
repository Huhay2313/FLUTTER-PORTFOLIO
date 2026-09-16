import 'package:flutter/material.dart';
import '../models/note.dart';
import '../db/db_helper.dart';

// NotesProvider — manages Activity 1 state.
// Fetches from SQLite and notifies the Activity 1 screen on changes.
class NotesProvider extends ChangeNotifier {
  final DbHelper _db = DbHelper.instance;
  List<Note> _notes = [];

  List<Note> get notes => List.unmodifiable(_notes);

  Future<void> loadNotes() async {
    _notes = await _db.fetchNotes();
    notifyListeners();
  }

  Future<void> addNote(String title, String body) async {
    final note = Note(
      title: title,
      body: body,
      createdAt: DateTime.now().toIso8601String(),
    );
    await _db.insertNote(note);
    await loadNotes();
  }

  Future<void> deleteNote(int id) async {
    await _db.deleteNote(id);
    await loadNotes();
  }

  Future<void> updateNote(Note note) async {
    await _db.updateNote(note);
    await loadNotes();
  }
}
