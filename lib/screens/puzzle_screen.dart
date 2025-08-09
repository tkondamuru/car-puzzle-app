import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:car_puzzle_app/models/puzzle.dart';
import 'package:car_puzzle_app/services/puzzle_service.dart';
import 'package:car_puzzle_app/services/stats_service.dart';
import 'package:car_puzzle_app/services/game_state.dart';
import 'package:dotted_border/dotted_border.dart';

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
  final GlobalKey _canvasKey = GlobalKey();
  int _pieceDropCounter = 0; // Track which side to drop pieces

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      final bool dropOnLeft = _pieceDropCounter % 2 == 1;
      
      if (dropOnLeft) {
        // Position on the left side
        position = Offset(
          50.0, // Left margin
          (canvasSize.height / 3) - (piece.bounds.height * _scale / 2),
        );
      } else {
        // Position on the right side
        position = Offset(
          canvasSize.width - (piece.bounds.width * _scale) - 50.0, // Right margin
          (canvasSize.height * 2 / 3) - (piece.bounds.height * _scale / 2),
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
    
    // Alternate between left and right positioning
    _pieceDropCounter++;
    final bool dropOnLeft = _pieceDropCounter % 2 == 1;
    
    final Offset newPosition;
    if (dropOnLeft) {
      // Position on the left side
      newPosition = Offset(
        50.0, // Left margin
        (canvasSize.height / 3) - (piece.bounds.height * _scale / 2),
      );
    } else {
      // Position on the right side
      newPosition = Offset(
        canvasSize.width - (piece.bounds.width * _scale) - 50.0, // Right margin
        (canvasSize.height * 2 / 3) - (piece.bounds.height * _scale / 2),
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
    _statsService.savePuzzleCompletion(puzzle.name, _elapsedSeconds);
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
    });
    _startTimer();
    
    // Always place g0 as the anchor after reset
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _selectRandomPiece(isAnchor: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
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
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showScaleSliderSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Adjust Puzzle Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.photo_size_select_small),
                      Expanded(
                        child: Slider(
                          value: _scale,
                          min: 0.1,
                          max: 1.0,
                          divisions: 9,
                          label: _scale.toStringAsFixed(1),
                          onChanged: (double value) {
                            // Use setState from the main screen state
                            setState(() {
                              _scale = value;
                            });
                            // Also update the modal sheet's state
                            setModalState(() {});
                          },
                        ),
                      ),
                      const Icon(Icons.photo_size_select_large),
                    ],
                  ),
                ],
              ),
            );
          },
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
              icon: const Icon(Icons.tune),
              onPressed: _showScaleSliderSheet,
              tooltip: 'Precise Size Control',
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
        floatingActionButton: FloatingActionButton(
          onPressed: _getNextPiece,
          tooltip: 'Tap: Get Next Piece / Reposition\nLong Press: Select Piece',
          child: GestureDetector(
            onLongPress: _showPieceDrawer,
            child: const Icon(Icons.extension),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
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
            if (index == 0) {
              Navigator.of(context).pop('home');
            } else if (index == 1) {
              Navigator.of(context).pop('dashboard');
            }
          },
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
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
                                    piece.thumbPath,
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
        ],
      );
    });
  }

  Widget _buildActivePiece() {
    if (_activePiece == null || _activePiecePosition == null) {
      return const SizedBox.shrink();
    }

    final piece = _activePiece!;
    // Use the full image path and bounds for the piece on the canvas
    final pieceWidget = Image.network(
      piece.imagePath,
      width: piece.bounds.width * _scale,
      height: piece.bounds.height * _scale,
      fit: BoxFit.contain,
    );

    return Positioned(
      left: _activePiecePosition!.dx,
      top: _activePiecePosition!.dy,
      child: GestureDetector(
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
    final anchorAbsPos = _anchorPiece!.bounds.topLeft;
    final currentPieceAbsPos = piece.bounds.topLeft;
    final relativeOffset = currentPieceAbsPos - anchorAbsPos;
    return _anchorPosition! + (relativeOffset * _scale);
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
    final randomMessage = celebrationMessages[
      math.Random().nextInt(celebrationMessages.length)
    ];
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(randomMessage),
        duration: const Duration(milliseconds: 1200),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
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
          onPanUpdate: (details) {
            setState(() {
              _anchorPosition = _anchorPosition! + details.delta;
            });
          },
          child: pieceWidget,
        );
      } else {
        // Add double-tap and long-press detection for non-anchor pieces
        pieceWidget = GestureDetector(
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
