import 'package:flutter/material.dart';
import '../models/checklist_item.dart';
import '../db/db_helper.dart';

// ChecklistProvider — manages Activity 2 state.
// Reads/writes SQLite and notifies the Activity 2 screen on every change.
class ChecklistProvider extends ChangeNotifier {
  final DbHelper _db = DbHelper.instance;
  List<ChecklistItem> _items = [];

  List<ChecklistItem> get items => List.unmodifiable(_items);

  int get doneCount => _items.where((i) => i.isDone).length;

  Future<void> loadItems() async {
    _items = await _db.fetchChecklistItems();
    notifyListeners();
  }

  Future<void> addItem(String label) async {
    final item = ChecklistItem(
      label: label,
      isDone: false,
      createdAt: DateTime.now().toIso8601String(),
    );
    await _db.insertChecklistItem(item);
    await loadItems();
  }

  Future<void> toggle(ChecklistItem item) async {
    await _db.toggleChecklistItem(item);
    await loadItems();
  }

  Future<void> deleteItem(int id) async {
    await _db.deleteChecklistItem(id);
    await loadItems();
  }
}
