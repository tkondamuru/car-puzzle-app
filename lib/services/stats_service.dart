import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class StatsService extends ChangeNotifier {
  late SharedPreferences _prefs;
  Map<String, int> _completionTimes = {};

  Map<String, int> get completionTimes => _completionTimes;

  StatsService() {
    _loadCompletionTimes();
  }

  Future<void> _loadCompletionTimes() async {
    _prefs = await SharedPreferences.getInstance();
    final keys = _prefs.getKeys();
    _completionTimes = {};
    for (String key in keys) {
      if (key.startsWith('puzzle_') && !key.endsWith('_state')) {
        final puzzleId = key.substring('puzzle_'.length);
        _completionTimes[puzzleId] = _prefs.getInt(key) ?? 0;
      }
    }
    notifyListeners();
  }

  Future<void> savePuzzleCompletion(String puzzleName, int time) async {
    _completionTimes[puzzleName] = time;
    await _prefs.setInt('puzzle_$puzzleName', time);
    notifyListeners();
  }

  int? getCompletionTime(String puzzleName) {
    return _completionTimes[puzzleName];
  }

  // New methods for completed puzzle state
  Future<void> saveCompletedPuzzleState(String puzzleId, Map<String, dynamic> state) async {
    final jsonState = json.encode(state);
    await _prefs.setString('puzzle_${puzzleId}_state', jsonState);
  }

  Future<Map<String, dynamic>?> getCompletedPuzzleState(String puzzleId) async {
    final jsonState = _prefs.getString('puzzle_${puzzleId}_state');
    if (jsonState != null) {
      return json.decode(jsonState) as Map<String, dynamic>;
    }
    return null;
  }

  bool isPuzzleCompleted(String puzzleId) {
    return _prefs.containsKey('puzzle_${puzzleId}_state');
  }

  Future<void> clearCompletedPuzzleState(String puzzleId) async {
    await _prefs.remove('puzzle_${puzzleId}_state');
    // Also remove the completion time
    _completionTimes.remove(puzzleId);
    await _prefs.remove('puzzle_$puzzleId');
    notifyListeners();
  }
}