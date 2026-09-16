import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import '../models/note.dart';
import '../models/checklist_item.dart';

// Singleton DB helper — opens once, reused across the app
class DbHelper {
  static final DbHelper instance = DbHelper._internal();
  DbHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return openDatabase(
        'labhub.db',
        version: 1,
        onCreate: _onCreate,
      );
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'labhub.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Activity 1 — Notes table
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Activity 2 — Checklist table
    await db.execute('''
      CREATE TABLE checklist (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL,
        is_done INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // ─── Notes CRUD ───────────────────────────────────────────────────────────

  Future<int> insertNote(Note note) async {
    final db = await database;
    return db.insert('notes', note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Note>> fetchNotes() async {
    final db = await database;
    final rows = await db.query('notes', orderBy: 'id DESC');
    return rows.map(Note.fromMap).toList();
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    return db.update('notes', note.toMap(),
        where: 'id = ?', whereArgs: [note.id]);
  }

  // ─── Checklist CRUD ───────────────────────────────────────────────────────

  Future<int> insertChecklistItem(ChecklistItem item) async {
    final db = await database;
    return db.insert('checklist', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ChecklistItem>> fetchChecklistItems() async {
    final db = await database;
    final rows = await db.query('checklist', orderBy: 'id DESC');
    return rows.map(ChecklistItem.fromMap).toList();
  }

  Future<int> deleteChecklistItem(int id) async {
    final db = await database;
    return db.delete('checklist', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> toggleChecklistItem(ChecklistItem item) async {
    final db = await database;
    return db.update(
      'checklist',
      item.copyWith(isDone: !item.isDone).toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }
}
