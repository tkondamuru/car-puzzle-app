import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:car_puzzle_app/models/puzzle.dart';
import 'package:car_puzzle_app/services/puzzle_service.dart';
import 'package:car_puzzle_app/services/stats_service.dart';
import 'package:car_puzzle_app/services/game_state.dart';
import 'package:dotted_border/dotted_border.dart';

const double SNAP_THRESHOLD = 25.0;

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

  PuzzlePiece? _draggedPiece;
  Offset? _dragPosition;

  double _scale = 0.5;
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      puzzle = ModalRoute.of(context)!.settings.arguments as Puzzle;
      _gameState = Provider.of<GameState>(context, listen: false);
      _statsService = Provider.of<StatsService>(context, listen: false);

      // Set this puzzle as the active puzzle in GameState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _gameState.setActivePuzzle(puzzle);
        }
      });
      _loadPuzzleData().then((_) => _loadState()); // Load state after puzzle data is loaded
      _startTimer();
      _isInitialized = true;
    }
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
    final puzzleService = PuzzleService();
    final puzzleData = await puzzleService.loadPuzzle(puzzle.id);
    setState(() {
      _puzzleData = puzzleData;
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
      _draggedPiece = null;
      _dragPosition = null;
    });
    _startTimer();
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(puzzle.name),
              Text(
                puzzle.desc,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
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
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildScaleSlider(),
                      _buildCanvasContainer(),
                      _buildThumbnailContainer(),
                    ],
                  ),
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

  Widget _buildScaleSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Size:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          Expanded(
            child: Slider(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasContainer() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: _buildCanvas(),
    );
  }

  Widget _buildThumbnailContainer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: _buildThumbnailPanel(),
    );
  }

  Widget _buildCanvas() {
    return DragTarget<PuzzlePiece>(
      key: _canvasKey,
      builder: (context, candidateData, rejectedData) {
        return LayoutBuilder(builder: (context, constraints) {
          return Stack(
            children: [
              ..._buildPlacedPieces(),
              if (_draggedPiece != null && _anchorPiece != null) _buildGhostPreview(),
            ],
          );
        });
      },
      onWillAcceptWithDetails: (details) => true,
      onMove: (details) {
        setState(() {
          _draggedPiece = details.data;
          _dragPosition = details.offset;
        });
      },
      onLeave: (data) {
        setState(() {
          _draggedPiece = null;
          _dragPosition = null;
        });
      },
      onAcceptWithDetails: (details) {
        final piece = details.data;
        final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return;

        final dropPosition = renderBox.globalToLocal(details.offset);

        if (_anchorPiece == null) {
          setState(() {
            _placedPieces.add(piece);
            _anchorPiece = piece;
            _anchorPosition = dropPosition;
            piece.isPlaced = true;
          });
        } else {
          final targetPos = _calculateTargetPosition(piece);
          if ((dropPosition - targetPos).distance < SNAP_THRESHOLD) {
            setState(() {
              _placedPieces.add(piece);
              piece.isPlaced = true;
            });
          }
        }

        if (_placedPieces.length == _puzzleData!.pieces.length) {
          _onPuzzleCompleted();
        }

        setState(() {
          _draggedPiece = null;
          _dragPosition = null;
        });
      },
    );
  }

  Offset _calculateTargetPosition(PuzzlePiece piece) {
    if (_anchorPiece == null || _anchorPosition == null) return Offset.zero;
    final anchorAbsPos = _anchorPiece!.bounds.topLeft;
    final currentPieceAbsPos = piece.bounds.topLeft;
    final relativeOffset = currentPieceAbsPos - anchorAbsPos;
    return _anchorPosition! + (relativeOffset * _scale);
  }

  List<Widget> _buildPlacedPieces() {
    if (_anchorPiece == null || _anchorPosition == null) return [];
    return _placedPieces.map((piece) {
      final position = _calculateTargetPosition(piece);

      Widget pieceWidget = Image.asset(
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

        // Make the anchor piece draggable
        pieceWidget = GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _anchorPosition = _anchorPosition! + details.delta;
            });
          },
          child: pieceWidget,
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
    if (_draggedPiece == null) return const SizedBox.shrink();

    final targetPos = _calculateTargetPosition(_draggedPiece!);
    final piece = _draggedPiece!;

    bool isCloseToSnap = false;
    if (_dragPosition != null) {
      final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final dropPosition = renderBox.globalToLocal(_dragPosition!);
        final adjustedDropPos = Offset(
          dropPosition.dx - (piece.bounds.width * _scale / 2),
          dropPosition.dy - (piece.bounds.height * _scale / 2),
        );
        if ((adjustedDropPos - targetPos).distance < SNAP_THRESHOLD) {
          isCloseToSnap = true;
        }
      }
    }

    return Positioned(
      left: targetPos.dx,
      top: targetPos.dy,
      width: piece.bounds.width * _scale,
      height: piece.bounds.height * _scale,
      child: DottedBorder(
        borderType: BorderType.RRect,
        radius: const Radius.circular(4),
        color: isCloseToSnap ? Colors.green.withOpacity(0.8) : Colors.black.withOpacity(0.3),
        strokeWidth: isCloseToSnap ? 3 : 2,
        dashPattern: const [6, 3],
        child: Opacity(
          opacity: 0.4,
          child: Image.asset(
            piece.imagePath,
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailPanel() {
    if (_puzzleData == null) return const SizedBox.shrink();

    return Wrap(
      spacing: 12.0,
      runSpacing: 8.0,
      alignment: WrapAlignment.center,
      children: _puzzleData!.pieces.map((piece) {
        final thumbImage = Image.asset(
          piece.thumbPath,
          width: piece.thumbBounds.width * _scale,
          height: piece.thumbBounds.height * _scale,
        );

        if (piece.isPlaced) {
          return Opacity(
            opacity: 0.5,
            child: thumbImage,
          );
        }

        return Draggable<PuzzlePiece>(
          data: piece,
          feedback: Image.asset(
            piece.imagePath,
            width: piece.bounds.width * _scale,
            height: piece.bounds.height * _scale,
            fit: BoxFit.contain,
          ),
          childWhenDragging: Opacity(
            opacity: 0.5,
            child: thumbImage,
          ),
          child: thumbImage,
        );
      }).toList(),
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