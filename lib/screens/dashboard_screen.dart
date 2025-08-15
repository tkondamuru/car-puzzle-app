import 'package:car_puzzle_app/models/puzzle.dart';
import 'package:car_puzzle_app/services/puzzle_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:car_puzzle_app/services/stats_service.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch stats when the screen is initialized
  }

  String _formatTime(int seconds) {
    final mins = (seconds / 60).floor().toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
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
                child: _buildCompletedPuzzlesList(),
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
            'Puzzle Champions',
            style: GoogleFonts.nunito(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'See all the puzzles you have conquered!',
            style: GoogleFonts.nunito(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedPuzzlesList() {
    final puzzleService = Provider.of<PuzzleService>(context, listen: false);

    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Consumer<StatsService>(
        builder: (context, statsService, child) {
          if (statsService.completionTimes.isEmpty) {
            return const Center(
              child: Text(
                'No puzzles completed yet. Go solve some!',
                style: TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            );
          }
          final completedPuzzles = statsService.completionTimes.entries.toList();
          return ListView.builder(
            itemCount: completedPuzzles.length,
            itemBuilder: (context, index) {
              final puzzleEntry = completedPuzzles[index];
              final puzzleId = puzzleEntry.key;
              final time = puzzleEntry.value;

              // Find the puzzle object
              Puzzle? puzzle;
              try {
                puzzle = puzzleService.puzzles.firstWhere((p) => p.id == puzzleId);
              } catch (e) {
                puzzle = null;
              }

              return ListTile(
                leading: const Icon(Icons.emoji_events, color: Colors.amber, size: 40),
                title: Text(
                  puzzle?.name ?? puzzleId,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Completed in: ${_formatTime(time)}',
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: ElevatedButton(
                  onPressed: puzzle == null ? null : () {
                    Navigator.pushNamed(context, '/puzzle', arguments: puzzle);
                  },
                  child: const Text('View'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}