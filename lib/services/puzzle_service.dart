import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/puzzle.dart';

class PuzzleService extends ChangeNotifier {
  List<Puzzle> _puzzles = [];
  List<Puzzle> get puzzles => _puzzles;

  Future<void> fetchPuzzles() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:8000/cars.js'));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        _puzzles = jsonList.map((json) => Puzzle.fromJson(json)).toList();
        notifyListeners();
      } else {
        print('Server error: ${response.statusCode}');
      }
    }
 catch (e) {
      print('Network error: $e');
    }
  }

  Future<PuzzleData> loadPuzzle(String puzzleId) async {
    final dimensionsString = await rootBundle.loadString('assets/puzzles/dimensions.txt');
    final lines = dimensionsString.split('\n');

    final boundsById = <String, Rect>{};
    for (final line in lines) {
      final parts = line.split(',');
      if (parts.length == 5) {
        final id = parts[0];
        final x = double.parse(parts[1]);
        final y = double.parse(parts[2]);
        final width = double.parse(parts[3]);
        final height = double.parse(parts[4]);
        boundsById[id] = Rect.fromLTWH(x, y, width, height);
      }
    }

    final puzzlePiecesBounds = boundsById.entries
        .where((entry) => entry.key.startsWith('g'))
        .map((entry) => entry.value)
        .toList();

    if (puzzlePiecesBounds.isEmpty) {
      throw Exception('No puzzle pieces found in dimensions.txt');
    }

    Rect overallBounds = puzzlePiecesBounds.first;
    for (var i = 1; i < puzzlePiecesBounds.length; i++) {
      overallBounds = overallBounds.expandToInclude(puzzlePiecesBounds[i]);
    }

    final pieces = <PuzzlePiece>[];
    boundsById.forEach((id, pieceBounds) {
      if (id.startsWith('g')) {
        final thumbId = id.replaceFirst('g', 't');
        final thumbBounds = boundsById[thumbId] ?? Rect.zero;

        pieces.add(PuzzlePiece(
          id: id,
          bounds: pieceBounds, // Absolute bounds
          thumbBounds: thumbBounds,
          imageBounds: pieceBounds, // Absolute bounds
          imagePath: 'assets/puzzles/${puzzleId}_$id.png',
          thumbPath: 'assets/puzzles/${puzzleId}_$thumbId.png',
        ));
      }
    });

    return PuzzleData(
      pieces: pieces,
      overallBounds: overallBounds,
      puzzleSize: overallBounds.size,
    );
  }
}
