import 'package:flutter/material.dart';

/// 🔥 GLOBAL INSTANCE (THIS IS WHAT YOU WERE MISSING)
final NavVisibilityController navController = NavVisibilityController();

class NavVisibilityController extends ChangeNotifier {
  bool _visible = true;

  bool get visible => _visible;

  void show() {
    if (!_visible) {
      _visible = true;
      notifyListeners();
    }
  }

  void hide() {
    if (_visible) {
      _visible = false;
      notifyListeners();
    }
  }
}
