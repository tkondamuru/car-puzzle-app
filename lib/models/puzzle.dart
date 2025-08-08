
import 'package:flutter/material.dart';

class Puzzle {
  final String id; // e.g., "puzzle-1754628029793"
  final String name; // e.g., "Classic Blue Sedan"
  final List<String> img;
  final int level;
  final String description;
  final int pieces;
  final List<String> tags;

  Puzzle({
    required this.id,
    required this.name,
    required this.img,
    required this.level,
    required this.description,
    required this.pieces,
    required this.tags,
  });

  factory Puzzle.fromJson(Map<String, dynamic> json) {
    return Puzzle(
      id: json['id'],
      name: json['name'],
      img: List<String>.from(json['img']),
      level: _levelToInt(json['level']),
      description: json['description'],
      pieces: json['pieces'],
      tags: json['tags'] is String ? (json['tags'] as String).split(',') : List<String>.from(json['tags']),
    );
  }

  static int _levelToInt(String level) {
    switch (level.toLowerCase()) {
      case 'easy':
        return 1;
      case 'medium':
        return 2;
      case 'hard':
        return 3;
      default:
        return 0;
    }
  }
}

class PuzzlePiece {
  final String id;
  // The absolute bounds of the piece from the original SVG coordinate system.
  final Rect bounds;
  final Rect thumbBounds; // Actual thumbnail bounds
  // The absolute bounds of the piece from the original SVG coordinate system. Same as `bounds`.
  final Rect imageBounds;
  final String imagePath;
  final String thumbPath;
  bool isPlaced;

  PuzzlePiece({
    required this.id,
    required this.bounds,
    required this.thumbBounds,
    required this.imageBounds,
    required this.imagePath,
    required this.thumbPath,
    this.isPlaced = false,
  });
}

class PuzzleData {
  final List<PuzzlePiece> pieces;
  // The combined bounding box of all puzzle pieces.
  final Rect overallBounds;
  final Size puzzleSize;

  PuzzleData({
    required this.pieces,
    required this.overallBounds,
    required this.puzzleSize,
  });
}
