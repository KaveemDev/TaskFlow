import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoriesNotifier extends Notifier<List<String>> {
  static const _prefsKey = 'custom_categories';
  static const _defaultCategories = ['Work', 'Personal'];

  @override
  List<String> build() {
    _loadCategories();
    return _defaultCategories; // Return defaults while loading
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    } else {
      state = List.from(_defaultCategories);
    }
  }

  Future<void> addCategory(String category) async {
    if (category.trim().isEmpty) return;
    final trimmed = category.trim();
    if (!state.contains(trimmed)) {
      final newState = [...state, trimmed];
      state = newState;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, newState);
    }
  }

  Future<void> removeCategory(String category) async {
    if (state.length <= 1) return;

    final newState = state.where((c) => c != category).toList();
    state = newState;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, newState);
  }
}

final categoriesProvider = NotifierProvider<CategoriesNotifier, List<String>>(
  CategoriesNotifier.new,
);
