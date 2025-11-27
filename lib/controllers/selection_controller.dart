import 'package:flutter/material.dart';

class SelectionController extends ChangeNotifier {
  int? _selectedProjectId;

  int? get selectedProjectId => _selectedProjectId;

  void selectProject(int? id) {
    _selectedProjectId = id;
    notifyListeners();
  }
}
