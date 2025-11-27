import 'package:flutter/material.dart';

class SelectedProjectController extends ChangeNotifier {
  int? _selectedId;
  int? get selectedId => _selectedId;

  void select(int? proyectoId) {
    _selectedId = proyectoId;
    notifyListeners();
  }

  void clear() {
    _selectedId = null;
    notifyListeners();
  }
}
