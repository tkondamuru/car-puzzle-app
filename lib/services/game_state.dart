import 'package:flutter/material.dart';
import '../models/puzzle.dart';

class GameState extends ChangeNotifier {
  Puzzle? _activePuzzle;
  Puzzle? get activePuzzle => _activePuzzle;

  // Saved state for the active puzzle
  Set<PuzzlePiece> _placedPieces = {};
  Set<PuzzlePiece> get placedPieces => _placedPieces;

  PuzzlePiece? _anchorPiece;
  PuzzlePiece? get anchorPiece => _anchorPiece;

  Offset? _anchorPosition;
  Offset? get anchorPosition => _anchorPosition;

  int _elapsedSeconds = 0;
  int get elapsedSeconds => _elapsedSeconds;

  // Navigation state
  String? _pendingNavigation;
  String? get pendingNavigation => _pendingNavigation;

  void setActivePuzzle(Puzzle puzzle) {
    // If it's a new puzzle (different ID), clear the old state.
    if (_activePuzzle?.id != puzzle.id) {
      clearPuzzleState();
      _activePuzzle = puzzle;
    } else {
      // Same puzzle, just update the reference
      _activePuzzle = puzzle;
    }
    notifyListeners();
  }

  void savePuzzleState({
    required Set<PuzzlePiece> placedPieces,
    required PuzzlePiece? anchorPiece,
    required Offset? anchorPosition,
    required int elapsedSeconds,
  }) {
    _placedPieces = Set.from(placedPieces);
    _anchorPiece = anchorPiece;
    _anchorPosition = anchorPosition;
    _elapsedSeconds = elapsedSeconds;
    notifyListeners();
  }

  void clearPuzzleState() {
    _placedPieces = {};
    _anchorPiece = null;
    _anchorPosition = null;
    _elapsedSeconds = 0;
  }

  void clearActivePuzzle() {
    _activePuzzle = null;
    clearPuzzleState();
    notifyListeners();
  }

  void setPendingNavigation(String? navigation) {
    _pendingNavigation = navigation;
    notifyListeners();
  }

  void clearPendingNavigation() {
    _pendingNavigation = null;
    notifyListeners();
  }
}