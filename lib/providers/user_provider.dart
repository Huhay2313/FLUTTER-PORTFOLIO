import 'package:flutter/material.dart';

// UserProvider — global state for the profile name.
// Settings screen writes here; Home Dashboard reads here via context.watch.
class UserProvider extends ChangeNotifier {
  String _name = 'Student';

  String get name => _name;

  void updateName(String newName) {
    if (newName.trim().isEmpty) return;
    _name = newName.trim();
    notifyListeners();
  }
}
