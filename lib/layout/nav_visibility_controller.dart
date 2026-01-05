import 'package:flutter/material.dart';

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

/// Global instance (shared controller)
final NavVisibilityController navController = NavVisibilityController();