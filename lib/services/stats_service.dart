
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class StatsService extends ChangeNotifier {
  SharedPreferences? _prefs;

  Map<String, int> _puzzleTimes = {};
  List<String> _completedPuzzles = [];

  Map<String, int> get puzzleTimes => _puzzleTimes;
  List<String> get completedPuzzles => _completedPuzzles;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadStats();
  }

  void _loadStats() {
    if (_prefs == null) return;
    _completedPuzzles = _prefs!.getStringList('completedPuzzles') ?? [];
    
    final times = _prefs!.getStringList('puzzleTimes') ?? [];
    _puzzleTimes = { for (var e in times) e.split(':')[0] : int.parse(e.split(':')[1]) };

    notifyListeners();
  }

  Future<void> savePuzzleCompletion(String puzzleId, int timeInSeconds) async {
    if (_prefs == null) await init();

    if (!_completedPuzzles.contains(puzzleId)) {
      _completedPuzzles.add(puzzleId);
      await _prefs!.setStringList('completedPuzzles', _completedPuzzles);
    }

    _puzzleTimes[puzzleId] = timeInSeconds;
    final List<String> times = _puzzleTimes.entries.map((e) => '${e.key}:${e.value}').toList();
    await _prefs!.setStringList('puzzleTimes', times);

    notifyListeners();
  }

  Future<void> resetStats() async {
    if (_prefs == null) await init();
    await _prefs!.clear();
    _puzzleTimes = {};
    _completedPuzzles = [];
    notifyListeners();
  }
}
