import 'package:flutter/material.dart';
import '../models/puzzle.dart';

class GameState extends ChangeNotifier {
  Puzzle? _activePuzzle;
  Puzzle? get activePuzzle => _activePuzzle;

  Set<PuzzlePiece> _placedPieces = {};
  Set<PuzzlePiece> get placedPieces => _placedPieces;

  PuzzlePiece? _anchorPiece;
  PuzzlePiece? get anchorPiece => _anchorPiece;

  Offset? _anchorPosition;
  Offset? get anchorPosition => _anchorPosition;

  int _elapsedSeconds = 0;
  int get elapsedSeconds => _elapsedSeconds;

  // New fields
  double _scale = 0.5;
  double get scale => _scale;

  double _rotation = 0.0;
  double get rotation => _rotation;

  bool _isAnchorLocked = false;
  bool get isAnchorLocked => _isAnchorLocked;

  String? _pendingNavigation;
  String? get pendingNavigation => _pendingNavigation;

  void setPendingNavigation(String target) {
    _pendingNavigation = target;
    notifyListeners();
  }

  void clearPendingNavigation() {
    _pendingNavigation = null;
  }

  void setActivePuzzle(Puzzle puzzle) {
    if (_activePuzzle?.id != puzzle.id) {
      _activePuzzle = puzzle;
      _placedPieces = {};
      _anchorPiece = null;
      _anchorPosition = null;
      _elapsedSeconds = 0;
      _scale = 0.5;
      _rotation = 0.0;
      _isAnchorLocked = true;
      notifyListeners();
    }
  }

  void savePuzzleState({
    required Set<PuzzlePiece> placedPieces,
    PuzzlePiece? anchorPiece,
    Offset? anchorPosition,
    required int elapsedSeconds,
    // New parameters
    double? scale,
    double? rotation,
    bool? isAnchorLocked,
  }) {
    _placedPieces = placedPieces;
    _anchorPiece = anchorPiece;
    _anchorPosition = anchorPosition;
    _elapsedSeconds = elapsedSeconds;
    // New assignments
    if (scale != null) _scale = scale;
    if (rotation != null) _rotation = rotation;
    if (isAnchorLocked != null) _isAnchorLocked = isAnchorLocked;
    notifyListeners();
  }

  void clearActivePuzzle() {
    _activePuzzle = null;
    _placedPieces = {};
    _anchorPiece = null;
    _anchorPosition = null;
    _elapsedSeconds = 0;
    _scale = 0.5;
    _rotation = 0.0;
    _isAnchorLocked = false;
    notifyListeners();
  }
}
