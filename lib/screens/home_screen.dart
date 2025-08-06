
import 'package:car_puzzle_app/services/game_state.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:car_puzzle_app/services/puzzle_service.dart';
import 'package:car_puzzle_app/models/puzzle.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  List<String> _selectedTags = [];
  List<String> _allTags = [];

  @override
  void initState() {
    super.initState();
    Provider.of<PuzzleService>(context, listen: false).fetchPuzzles().then((_) {
      setState(() {
        _allTags = Provider.of<PuzzleService>(context, listen: false)
            .puzzles
            .expand((p) => p.tags)
            .toSet()
            .toList();
      });
    });
  }

  List<Puzzle> _getFilteredPuzzles() {
    final puzzleService = Provider.of<PuzzleService>(context);
    return puzzleService.puzzles.where((puzzle) {
      final query = _searchQuery.toLowerCase();
      final nameMatch = puzzle.name.toLowerCase().contains(query);
      final descMatch = puzzle.desc.toLowerCase().contains(query);
      final tagsMatch = _selectedTags.isEmpty || puzzle.tags.any((tag) => _selectedTags.contains(tag));
      return (nameMatch || descMatch) && tagsMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8A2BE2), Color(0xFFFF69B4), Color(0xFFFFA500)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildSearchAndFilter(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildPuzzleList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
      child: Column(
        children: [
          Text(
            'Kids Puzzle Palace',
            style: GoogleFonts.nunito(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Solve amazing puzzles and become a puzzle master!',
            style: GoogleFonts.nunito(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzleList() {
    final filteredPuzzles = _getFilteredPuzzles();

    return filteredPuzzles.isEmpty
        ? const Center(child: Text('No puzzles found.'))
        : GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 250,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: filteredPuzzles.length,
            itemBuilder: (context, index) {
              return _buildPuzzleCard(filteredPuzzles[index]);
            },
          );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search puzzles...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[200],
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _showTagFilterSheet,
          icon: const Icon(Icons.filter_list),
          label: const Text('Filter'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pinkAccent,
            //add white color to text
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  void _showTagFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _allTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (selected) {
                      setModalState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                      setState(() {}); // Rebuild the main screen to apply the filter
                    },
                    selectedColor: Colors.pinkAccent,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPuzzleCard(Puzzle puzzle) {
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
            child: Tooltip(
              message: puzzle.desc,
              child: Text(
                puzzle.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: SvgPicture.network(
                'http://localhost:8000/${puzzle.img}',
                fit: BoxFit.contain,
                placeholderBuilder: (BuildContext context) => const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${puzzle.pieces} pieces', style: const TextStyle(fontSize: 12)),
                ElevatedButton(
                  onPressed: () {
                    final gameState = Provider.of<GameState>(context, listen: false);
                    gameState.setActivePuzzle(puzzle);
                    Navigator.pushNamed(context, '/puzzle', arguments: puzzle).then((result) {
                      // Handle navigation result
                      if (result != null && mounted) {
                        gameState.setPendingNavigation(result.toString());
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Start', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
