import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/puzzle.dart';

const String baseUrl = 'https://puzzle-assets.agility-maint.net';

class PuzzleService extends ChangeNotifier {
  List<Puzzle> _puzzles = [];
  List<Puzzle> get puzzles => _puzzles;

  Future<void> fetchPuzzles() async {
    try {
      final response = await http.get(Uri.parse('https://puzzle-manager.agility-maint.net/puzzles'));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        _puzzles = jsonList.map((json) => Puzzle.fromJson(json)).toList();
        notifyListeners();
      } else {
        print('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Network error while fetching puzzles: $e');
    }
  }

  Future<PuzzleData?> loadPuzzle(String puzzleId) async {
    final puzzle = _puzzles.firstWhere((p) => p.id == puzzleId, orElse: () => throw Exception('Puzzle not found'));
    final dimensionsPath = puzzle.img.firstWhere((path) => path.endsWith('dimensions.txt'), orElse: () => '');

    if (dimensionsPath.isEmpty) {
      return PuzzleData(
        pieces: [],
        overallBounds: Rect.zero,
        puzzleSize: Size.zero,
      );
    }

    final dimensionsUrl = '$baseUrl/$dimensionsPath';
    final dimensionsResponse = await http.get(Uri.parse(dimensionsUrl));
    if (dimensionsResponse.statusCode != 200) {
      print('Failed to load dimensions.txt: ${dimensionsResponse.statusCode}');
      return PuzzleData(
        pieces: [],
        overallBounds: Rect.zero,
        puzzleSize: Size.zero,
      );
    }

    final dimensionsString = dimensionsResponse.body;
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
      return PuzzleData(
        pieces: [],
        overallBounds: Rect.zero,
        puzzleSize: Size.zero,
      );
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

        final imagePathFragment = puzzle.img.firstWhere(
            (path) => path.contains('_$id.'), orElse: () => '');
        
        final thumbPathFragment = puzzle.img.firstWhere(
            (path) => path.contains('_$thumbId.'), orElse: () => '');

        if (imagePathFragment.isNotEmpty && thumbPathFragment.isNotEmpty) {
             pieces.add(PuzzlePiece(
                id: id,
                bounds: pieceBounds, // Absolute bounds
                thumbBounds: thumbBounds,
                imageBounds: pieceBounds, // Absolute bounds
                imagePath: '$baseUrl/$imagePathFragment',
                thumbPath: '$baseUrl/$thumbPathFragment',
            ));
        }
      }
    });

    return PuzzleData(
      pieces: pieces,
      overallBounds: overallBounds,
      puzzleSize: overallBounds.size,
    );
  }
}
