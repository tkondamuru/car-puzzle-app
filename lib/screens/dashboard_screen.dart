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
    Provider.of<StatsService>(context, listen: false).init();
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
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Consumer<StatsService>(
        builder: (context, statsService, child) {
          if (statsService.completedPuzzles.isEmpty) {
            return const Center(
              child: Text(
                'No puzzles completed yet. Go solve some!',
                style: TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            itemCount: statsService.completedPuzzles.length,
            itemBuilder: (context, index) {
              final puzzleId = statsService.completedPuzzles[index];
              final time = statsService.puzzleTimes[puzzleId] ?? 0;
              return ListTile(
                leading: const Icon(Icons.emoji_events, color: Colors.amber, size: 40),
                title: Text(
                  puzzleId,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Completed in: ${_formatTime(time)}',
                  style: const TextStyle(color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}