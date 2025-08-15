import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:car_puzzle_app/models/puzzle.dart';
import 'package:car_puzzle_app/services/puzzle_service.dart';
import 'package:car_puzzle_app/services/stats_service.dart';
import 'package:car_puzzle_app/services/game_state.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:confetti/confetti.dart';

enum ControlMode { scale, rotate, lock }

const double SNAP_THRESHOLD = 25.0;

const List<String> celebrationMessages = [
  "🎉 Complete! 🎉", "🌟 Awesome! 🌟", "🎯 Nailed It!", "🏁 You Did It!",
  "🚀 Well Done!", "🥳 Great Job!", "💫 Puzzle Solved!", "🔥 That Was Fast!",
  "🎈 Fantastic!", "✅ All Set!", "💥 Boom! Complete!", "👏 Bravo!",
  "🧠 Smart Move!", "🎮 Victory!", "✨ Excellent Work!", "🎊 You Rock!",
  "🎵 That Was Smooth!", "🍭 Sweet Success!", "🧩 Puzzle Master!",
  "🌈 Magic Move!", "🏆 Champion!", "🎨 Masterpiece!", "🎤 Mic Drop!",
  "😎 Too Cool!", "🔓 Unlocked!", "🦄 Nailed the Magic!", "🥇 First Place!",
  "🌟 Superstar!", "🛸 Out of This World!"
];

const List<Color> celebrationColors = [
  Colors.pink,
  Colors.orange,
  Colors.green,
  Colors.blue,
  Colors.purple,
  Colors.red,
];

class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> with WidgetsBindingObserver, RouteAware {
  late Puzzle puzzle;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isInitialized = false;

  late GameState _gameState;
  late StatsService _statsService;

  PuzzleData? _puzzleData;
  Set<PuzzlePiece> _placedPieces = {};
  PuzzlePiece? _anchorPiece;
  Offset? _anchorPosition;

  PuzzlePiece? _activePiece;
  Offset? _activePiecePosition;

  bool _showGhost = false;

  double _scale = 0.5;
  double _rotation = 0.0; // in radians
  final GlobalKey _canvasKey = GlobalKey();
  int _pieceDropCounter = 0; // Track which side to drop pieces

  String? _celebrationMessage;
  Color? _celebrationColor;
  Timer? _celebrationTimer;

  // New state variables for unified controls
  ControlMode _controlMode = ControlMode.scale;
  bool _isAnchorLocked = true;

  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController = ConfettiController(duration: const Duration(seconds: 10));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      puzzle = ModalRoute.of(context)!.settings.arguments as Puzzle;
      _gameState = Provider.of<GameState>(context, listen: false);
      _statsService = Provider.of<StatsService>(context, listen: false);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeGame();
      });
    }
  }

  Future<void> _initializeGame() async {
    if (!mounted) return;
    _gameState.setActivePuzzle(puzzle);
    
    await _loadPuzzleData();
    if (!mounted) return;

    if (_statsService.isPuzzleCompleted(puzzle.id)) {
      final completedState = await _statsService.getCompletedPuzzleState(puzzle.id);
      if (completedState != null && mounted) {
        setState(() {
          _scale = completedState['scale'];
          _rotation = completedState['rotation'];
          _anchorPosition = Offset(completedState['anchorPosition']['dx'], completedState['anchorPosition']['dy']);
          
          final anchorId = completedState['anchorId'];
          _anchorPiece = _puzzleData!.pieces.firstWhere((p) => p.id == anchorId);

          // Mark all pieces as placed
          _placedPieces = Set.from(_puzzleData!.pieces);
          for (var piece in _puzzleData!.pieces) {
            piece.isPlaced = true;
          }
          
          _timer?.cancel(); // Stop timer for completed puzzles
          _showRandomCelebration(); // Show a celebration message
          _playConfetti();
        });
        return; // Skip normal initialization
      }
    }

    _loadState();
    if (!mounted) return;

    // After the data is loaded and state is restored, wait for the next frame
    // to ensure the canvas is built before we try to place the first piece.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _placedPieces.isEmpty && _activePiece == null) {
        _selectRandomPiece(isAnchor: true);
      }
    });

    _startTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _saveState();
    } else if (state == AppLifecycleState.resumed) {
      _startTimer();
    }
  }

  void _loadState() {
    if (_gameState.activePuzzle?.id == puzzle.id) {
      setState(() {
        _placedPieces = Set.from(_gameState.placedPieces);
        _anchorPiece = _gameState.anchorPiece;
        _anchorPosition = _gameState.anchorPosition;
        _elapsedSeconds = _gameState.elapsedSeconds;
        _scale = _gameState.scale;
        _rotation = _gameState.rotation;
        _isAnchorLocked = _gameState.isAnchorLocked;
        
        // Update piece isPlaced status based on saved state
        if (_puzzleData != null) {
          for (var piece in _puzzleData!.pieces) {
            piece.isPlaced = _placedPieces.any((placedPiece) => placedPiece.id == piece.id);
          }
        }
      });
    }
  }

  void _saveState() {
    _gameState.savePuzzleState(
      placedPieces: _placedPieces,
      anchorPiece: _anchorPiece,
      anchorPosition: _anchorPosition,
      elapsedSeconds: _elapsedSeconds,
      scale: _scale,
      rotation: _rotation,
      isAnchorLocked: _isAnchorLocked,
    );
  }

  Future<void> _loadPuzzleData() async {
    final puzzleService = Provider.of<PuzzleService>(context, listen: false);
    final puzzleData = await puzzleService.loadPuzzle(puzzle.id);
    if (mounted) {
      setState(() {
        _puzzleData = puzzleData;
        if (_puzzleData == null || _puzzleData!.pieces.isEmpty) {
          // Handle case where puzzle data is not available
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Puzzle is not ready yet.')),
          );
        }
      });
    }
  }

  void _selectRandomPiece({bool isAnchor = false}) {
    final unplacedPieces = _puzzleData?.pieces.where((p) => !p.isPlaced).toList();
    
    if (unplacedPieces == null || unplacedPieces.isEmpty) {
      return;
    }

    PuzzlePiece piece;
    if (isAnchor) {
      // Always start with g0 piece as anchor
      piece = _puzzleData!.pieces.firstWhere(
        (p) => p.id == 'g0' && !p.isPlaced,
        orElse: () => unplacedPieces.first,
      );
    } else {
      // Get next available piece (ordered by ID for predictability)
      piece = unplacedPieces.first;
    }

    final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final canvasSize = renderBox.size;
    
    Offset position;
    if (isAnchor || _anchorPiece == null) {
      // Place anchor piece in center
      position = Offset(
        (canvasSize.width / 2) - (piece.bounds.width * _scale / 2),
        (canvasSize.height / 2) - (piece.bounds.height * _scale / 2),
      );
    } else {
      // Use alternating positioning for new pieces
      _pieceDropCounter++;
      final bool dropAtBottomLeft = _pieceDropCounter % 2 == 1;
      
      if (dropAtBottomLeft) {
        // Position at the bottom-left corner
        position = Offset(
          50.0, // Left margin
          canvasSize.height - (piece.bounds.height * _scale) - 50.0, // Bottom margin
        );
      } else {
        // Position at the top-right corner
        position = Offset(
          canvasSize.width - (piece.bounds.width * _scale) - 50.0, // Right margin
          50.0, // Top margin
        );
      }
    }

    setState(() {
      if (isAnchor || _anchorPiece == null) {
        // This is the first piece, it becomes the anchor and is immediately placed.
        _anchorPiece = piece;
        _anchorPosition = position;
        _placedPieces.add(piece);
        piece.isPlaced = true;
      } else {
        // This is a subsequent piece.
        _activePiece = piece;
        _activePiecePosition = position;
      }
    });
  }

  void _getNextPiece() {
    if (_activePiece != null) {
      // If there's already an active piece, reposition it
      _repositionActivePiece();
      return;
    }
    _selectRandomPiece();
  }

  void _repositionActivePiece() {
    if (_activePiece == null) return;
    
    final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final canvasSize = renderBox.size;
    final piece = _activePiece!;
    
    // Alternate between bottom-left and top-right positioning
    _pieceDropCounter++;
    final bool dropAtBottomLeft = _pieceDropCounter % 2 == 1;
    
    final Offset newPosition;
    if (dropAtBottomLeft) {
      // Position at the bottom-left corner
      newPosition = Offset(
        50.0, // Left margin
        canvasSize.height - (piece.bounds.height * _scale) - 50.0, // Bottom margin
      );
    } else {
      // Position at the top-right corner
      newPosition = Offset(
        canvasSize.width - (piece.bounds.width * _scale) - 50.0, // Right margin
        50.0, // Top margin
      );
    }
    
    setState(() {
      _activePiecePosition = newPosition;
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_placedPieces.length < (_puzzleData?.pieces.length ?? 0)) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  void _onPuzzleCompleted() {
    _timer?.cancel();
    _statsService.savePuzzleCompletion(puzzle.id, _elapsedSeconds);
    _playConfetti();
    
    // Save completed state
    if (_anchorPiece != null && _anchorPosition != null) {
      final completedState = {
        'anchorId': _anchorPiece!.id,
        'anchorPosition': {
          'dx': _anchorPosition!.dx,
          'dy': _anchorPosition!.dy,
        },
        'scale': _scale,
        'rotation': _rotation,
      };
      _statsService.saveCompletedPuzzleState(puzzle.id, completedState);
    }

    _gameState.clearActivePuzzle();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Puzzle Completed!'),
        content: Text('You solved the puzzle in $_elapsedSeconds seconds.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }

  void _resetPuzzle() {
    _confettiController.stop();
    // Clear completed state from stats service
    _statsService.clearCompletedPuzzleState(puzzle.id);

    setState(() {
      _placedPieces.clear();
      for (var piece in _puzzleData?.pieces ?? []) {
        piece.isPlaced = false;
      }
      _anchorPiece = null;
      _anchorPosition = null;
      _elapsedSeconds = 0;
      _activePiece = null;
      _activePiecePosition = null;
      _showGhost = false;
      _pieceDropCounter = 0; // Reset piece positioning counter
      // Reset UI controls to default
      _scale = 0.5;
      _rotation = 0.0;
      _isAnchorLocked = true;
    });

    // Also clear the session state
    _saveState();

    _startTimer();
    
    // Always place g0 as the anchor after reset
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _selectRandomPiece(isAnchor: true);
      }
    });
  }

  void _playConfetti() {
    _confettiController.play();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _celebrationTimer?.cancel();
    _confettiController.dispose();
    // State is saved in other lifecycle methods like didChangeAppLifecycleState, onWillPop, etc.
    super.dispose();
  }

  String _formatTime(int seconds) {
    final mins = (seconds / 60).floor().toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _showPuzzleInfoSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                puzzle.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                puzzle.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              const Text(
                'How to Play:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text('• Drag pieces to snap them together'),
              const Text('• Long press FAB to select specific pieces'),
              const Text('• Green piece is the anchor - drag it to move all pieces'),
              const Text('• Double-tap or long-press any snapped piece to make it the new anchor'),
              const Text('• Use the tune button for precise size control'),
              const Text('• For best experience, drag items by their center.'),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    final bool isGameActive = gameState.activePuzzle != null;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _saveState();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Game!'),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showPuzzleInfoSheet,
              tooltip: 'About Puzzle',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetPuzzle,
              tooltip: 'Restart Puzzle',
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '${_placedPieces.length} / ${_puzzleData?.pieces.length ?? 0}',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(_formatTime(_elapsedSeconds), style: const TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8A2BE2), Color(0xFFFF69B4), Color(0xFFFFA500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: _puzzleData == null
              ? const Center(child: CircularProgressIndicator())
              : _buildCanvasContainer(),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildControlPanel(),
            BottomNavigationBar(
              items: <BottomNavigationBarItem>[
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.gamepad, color: isGameActive ? Colors.blueAccent : Colors.grey),
                  label: 'My Game',
                ),
              ],
              currentIndex: 2, // Always highlight "My Game"
              selectedItemColor: Colors.blueAccent,
              onTap: (index) {
                _saveState(); // Save state before navigating
                final gameState = Provider.of<GameState>(context, listen: false);
                if (index == 0) {
                  gameState.setPendingNavigation('home');
                  Navigator.of(context).pop();
                } else if (index == 1) {
                  gameState.setPendingNavigation('dashboard');
                  Navigator.of(context).pop();
                }
              },
              type: BottomNavigationBarType.fixed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Material(
      color: Theme.of(context).bottomAppBarTheme.color,
      elevation: 8.0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            FloatingActionButton(
              heroTag: 'controlModeFab',
              mini: true,
              onPressed: () {
                setState(() {
                  if (_controlMode == ControlMode.scale) {
                    _controlMode = ControlMode.rotate;
                  } else if (_controlMode == ControlMode.rotate) {
                    _controlMode = ControlMode.lock;
                  } else {
                    _controlMode = ControlMode.scale;
                  }
                });
              },
              tooltip: _getControlModeTooltip(),
              child: Icon(_getControlModeIcon()),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _buildMiddleControl(),
              ),
            ),
            FloatingActionButton(
              heroTag: 'pieceFab',
              onPressed: _getNextPiece,
              tooltip: 'Tap: Get Next Piece / Reposition\nLong Press: Select Piece',
              child: GestureDetector(
                onLongPress: _showPieceDrawer,
                child: const Icon(Icons.extension),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getControlModeTooltip() {
    switch (_controlMode) {
      case ControlMode.scale:
        return 'Switch to Rotate';
      case ControlMode.rotate:
        return 'Switch to Lock Anchor';
      case ControlMode.lock:
        return 'Switch to Scale';
    }
  }

  IconData _getControlModeIcon() {
    switch (_controlMode) {
      case ControlMode.scale:
        return Icons.aspect_ratio;
      case ControlMode.rotate:
        return Icons.rotate_90_degrees_ccw;
      case ControlMode.lock:
        return _isAnchorLocked ? Icons.lock : Icons.lock_open;
    }
  }

  Widget _buildMiddleControl() {
    switch (_controlMode) {
      case ControlMode.scale:
        return Slider(
          value: _scale,
          min: 0.1,
          max: 1.0,
          divisions: 9,
          label: _scale.toStringAsFixed(1),
          onChanged: (double value) {
            setState(() {
              _scale = value;
            });
          },
        );
      case ControlMode.rotate:
        return Slider(
          value: _rotation,
          min: -math.pi,
          max: math.pi,
          divisions: 36,
          label: (_rotation * 180 / math.pi).toStringAsFixed(0) + '°',
          onChanged: (double value) {
            setState(() {
              _rotation = value;
            });
          },
        );
      case ControlMode.lock:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_isAnchorLocked ? 'Anchor Locked' : 'Anchor Unlocked', style: const TextStyle(fontWeight: FontWeight.bold)),
            Switch(
              value: _isAnchorLocked,
              onChanged: (bool value) {
                setState(() {
                  _isAnchorLocked = value;
                });
              },
            ),
          ],
        );
    }
  }

  Widget _buildCanvasContainer() {
    return Container(
      // Make it occupy the full screen
      height: double.infinity,
      width: double.infinity,
      margin: const EdgeInsets.all(4.0),
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _buildCanvas(),
    );
  }

  void _showPieceDrawer() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final unplacedPieces = _puzzleData?.pieces
                .where((p) => !_placedPieces.contains(p) && p.id != _activePiece?.id)
                .toList() ?? [];

            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Select a Piece',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 100,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: unplacedPieces.length,
                      itemBuilder: (context, index) {
                        final piece = unplacedPieces[index];
                        return GestureDetector(
                          onTap: () {
                            final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                            if (renderBox == null) return;
                            final canvasSize = renderBox.size;
                            final position = Offset(
                              (canvasSize.width / 2) - (piece.bounds.width * _scale / 2),
                              (canvasSize.height / 2) - (piece.bounds.height * _scale / 2),
                            );

                            setState(() {
                              if (_anchorPiece == null) {
                                _anchorPiece = piece;
                                _anchorPosition = position;
                                _placedPieces.add(piece);
                                piece.isPlaced = true;
                              } else {
                                _activePiece = piece;
                                _activePiecePosition = position;
                              }
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4.0),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Image.network(
                                    piece.imagePath,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                Text(
                                  piece.id,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        key: _canvasKey,
        children: [
          ..._buildPlacedPieces(),
          _buildGhostPreview(),
          _buildActivePiece(),
          _buildCelebrationMessage(),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.02,
              numberOfParticles: 40,
              gravity: 0.5,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildCelebrationMessage() {
    if (_celebrationMessage == null) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _celebrationColor ?? Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _celebrationMessage!,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActivePiece() {
    if (_activePiece == null || _activePiecePosition == null) {
      return const SizedBox.shrink();
    }

    final piece = _activePiece!;
    final pieceWidget = Transform.rotate(
      angle: _rotation,
      child: Image.network(
        piece.imagePath,
        width: piece.bounds.width * _scale,
        height: piece.bounds.height * _scale,
        fit: BoxFit.contain,
      ),
    );

    return Positioned(
      left: _activePiecePosition!.dx,
      top: _activePiecePosition!.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (details) {
          // Show ghost immediately on long press start
          setState(() {
            _showGhost = true;
          });
        },
        onLongPressEnd: (details) {
          // Hide ghost immediately when long press ends
          setState(() {
            _showGhost = false;
          });
        },
        onPanStart: (details) {
          // Hide ghost when starting to drag
          setState(() {
            _showGhost = false;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _activePiecePosition = _activePiecePosition! + details.delta;
          });
        },
        onPanEnd: (details) {
          // Check for snap on drag end
          final targetPos = _calculateTargetPosition(piece);
          if ((_activePiecePosition! - targetPos).distance < SNAP_THRESHOLD) {
            setState(() {
              _placedPieces.add(piece);
              piece.isPlaced = true;
              _activePiece = null;
              _activePiecePosition = null;
            });
            
            // Show celebration message for successful snap
            _showRandomCelebration();

            if (_placedPieces.length == _puzzleData!.pieces.length) {
              _onPuzzleCompleted();
            }
          }
        },
        child: pieceWidget,
      ),
    );
  }

  Offset _calculateTargetPosition(PuzzlePiece piece) {
    if (_anchorPiece == null || _anchorPosition == null) return Offset.zero;

    // 1. Define centers in puzzle space (from JSON data)
    final anchorCenterPuzzle = _anchorPiece!.bounds.center;
    final pieceCenterPuzzle = piece.bounds.center;

    // 2. Calculate the vector from the anchor's center to the piece's center
    final relativeCenterVector = pieceCenterPuzzle - anchorCenterPuzzle;

    // 3. Scale this vector
    final scaledRelativeVector = relativeCenterVector * _scale;

    // 4. Rotate this vector
    final cosR = math.cos(_rotation);
    final sinR = math.sin(_rotation);
    final rotatedDx = scaledRelativeVector.dx * cosR - scaledRelativeVector.dy * sinR;
    final rotatedDy = scaledRelativeVector.dx * sinR + scaledRelativeVector.dy * cosR;
    final rotatedRelativeVector = Offset(rotatedDx, rotatedDy);

    // 5. Find the anchor's center on the canvas
    final anchorCenterCanvas = _anchorPosition! + (_anchorPiece!.bounds.size.center(Offset.zero) * _scale);

    // 6. Calculate the piece's new center on the canvas
    final pieceCenterCanvas = anchorCenterCanvas + rotatedRelativeVector;

    // 7. Calculate the piece's top-left for the Positioned widget
    final pieceTopLeftCanvas = pieceCenterCanvas - (piece.bounds.size.center(Offset.zero) * _scale);

    return pieceTopLeftCanvas;
  }

  void _switchAnchor(PuzzlePiece newAnchorPiece) {
    if (_anchorPiece == null || _anchorPosition == null) return;
    if (newAnchorPiece == _anchorPiece) return; // Already the anchor
    
    // Calculate the current position of the new anchor piece
    final newAnchorCurrentPosition = _calculateTargetPosition(newAnchorPiece);
    
    setState(() {
      // Update anchor piece and position
      _anchorPiece = newAnchorPiece;
      _anchorPosition = newAnchorCurrentPosition;
    });
    
    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Anchor changed to piece ${newAnchorPiece.id}'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showRandomCelebration() {
    _celebrationTimer?.cancel();
    final randomMessage = celebrationMessages[math.Random().nextInt(celebrationMessages.length)];
    final randomColor = celebrationColors[math.Random().nextInt(celebrationColors.length)];

    setState(() {
      _celebrationMessage = randomMessage;
      _celebrationColor = randomColor;
    });

    _celebrationTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _celebrationMessage = null;
        });
      }
    });
  }

  List<Widget> _buildPlacedPieces() {
    if (_anchorPiece == null || _anchorPosition == null) return [];
    return _placedPieces.map((piece) {
      final position = _calculateTargetPosition(piece);

      Widget pieceWidget = Image.network(
        piece.imagePath,
        width: piece.bounds.width * _scale,
        height: piece.bounds.height * _scale,
        fit: BoxFit.fill,
      );
      pieceWidget = Transform.rotate(
        angle: _rotation,
        child: pieceWidget,
      );

      if (piece == _anchorPiece) {
        // Apply green tint to the anchor piece
        pieceWidget = ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.green.withOpacity(0.5),
            BlendMode.modulate,
          ),
          child: pieceWidget,
        );

        // Make the anchor piece draggable (removed pinch-to-zoom)
        pieceWidget = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: _isAnchorLocked ? null : (details) {
            setState(() {
              _anchorPosition = _anchorPosition! + details.delta;
            });
          },
          child: pieceWidget,
        );
      } else {
        // Add double-tap and long-press detection for non-anchor pieces
        pieceWidget = GestureDetector(
          behavior: HitTestBehavior.translucent, // Allow gestures to pass through
          onDoubleTap: () => _switchAnchor(piece),
          onLongPress: () => _switchAnchor(piece),
          child: Container(
            child: pieceWidget,
          ),
        );
      }

      return Positioned(
        left: position.dx,
        top: position.dy,
        child: pieceWidget,
      );
    }).toList();
  }

  Widget _buildGhostPreview() {
    if (!_showGhost || _activePiece == null) return const SizedBox.shrink();

    final targetPos = _calculateTargetPosition(_activePiece!);
    final piece = _activePiece!;

    return Positioned(
      left: targetPos.dx,
      top: targetPos.dy,
      width: piece.bounds.width * _scale,
      height: piece.bounds.height * _scale,
      child: Transform.rotate(
        angle: _rotation,
        child: DottedBorder(
          borderType: BorderType.RRect,
          radius: const Radius.circular(4),
          color: Colors.green.withOpacity(0.8),
          strokeWidth: 3,
          dashPattern: const [6, 3],
          child: Opacity(
            opacity: 0.4,
            child: Image.network(
              piece.imagePath,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    );
  }

  // RouteAware methods
  @override
  void didPushNext() {
    // Called when a new route is pushed on top of this route
    _saveState();
  }

  @override
  void didPopNext() {
    // Called when the top route is popped and this route is now on top
    // Reload state in case anything changed
    _loadState();
  }

  @override
  void didPush() {
    // Called when this route is pushed onto the navigator
  }

  @override
  void didPop() {
    // Called when this route is popped from the navigator
    _saveState();
  }
}
