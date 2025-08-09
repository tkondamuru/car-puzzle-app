
import 'package:car_puzzle_app/services/game_state.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:car_puzzle_app/services/puzzle_service.dart';
import 'package:car_puzzle_app/models/puzzle.dart';

//const String baseUrl = 'https://puzzle-assets.agility-maint.net';
const String baseUrl = 'https://pub-0190997ca1814eaf8cb0bffd73e7abb2.r2.dev';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  late final TextEditingController _searchController;
  List<String> _selectedTags = [];
  List<String> _allTags = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _searchQuery);
    Provider.of<PuzzleService>(context, listen: false).fetchPuzzles().then((_) {
      if (mounted) {
        setState(() {
          _allTags = Provider.of<PuzzleService>(context, listen: false)
              .puzzles
              .expand((p) => p.tags)
              .toSet()
              .toList();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Puzzle> _getFilteredPuzzles() {
    final puzzleService = Provider.of<PuzzleService>(context);
    return puzzleService.puzzles.where((puzzle) {
      final query = _searchQuery.toLowerCase();
      final nameMatch = puzzle.name.toLowerCase().contains(query);
      final descMatch = puzzle.description.toLowerCase().contains(query);
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
                  margin: const EdgeInsets.all(8.0),
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
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
      padding: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Puzzle Palace',
            style: GoogleFonts.nunito(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 30),
            onPressed: _showSearchAndFilterSheet,
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

  void _showSearchAndFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16.0,
                right: 16.0,
                top: 16.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      _searchQuery = value;
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
                    onEditingComplete: () {
                      setState(() {});
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
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
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      setState(() {}); // Ensure the UI updates with the new search query
    });
  }

  Future<void> _startPuzzle(Puzzle puzzle) async {
    final hasDimensions = puzzle.img.any((path) => path.endsWith('dimensions.txt'));

    if (hasDimensions) {
      if (mounted) {
        final gameState = Provider.of<GameState>(context, listen: false);
        gameState.setActivePuzzle(puzzle);
        Navigator.pushNamed(context, '/puzzle', arguments: puzzle).then((result) {
          if (result != null && mounted) {
            gameState.setPendingNavigation(result.toString());
          }
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Puzzle is building, please try again later.')),
        );
      }
    }
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
              message: puzzle.description,
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
                '$baseUrl/${puzzle.img.firstWhere((path) => path.endsWith('.svg'), orElse: () => '')}',
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
                Chip(
                  label: Text('${puzzle.pieces}'),
                  backgroundColor: Colors.pinkAccent.withOpacity(0.2),
                  labelStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
                ElevatedButton(
                  onPressed: () => _startPuzzle(puzzle),
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
