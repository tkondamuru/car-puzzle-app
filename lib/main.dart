import 'package:car_puzzle_app/models/puzzle.dart';
import 'package:car_puzzle_app/screens/dashboard_screen.dart';
import 'package:car_puzzle_app/screens/home_screen.dart';
import 'package:car_puzzle_app/screens/puzzle_screen.dart';
import 'package:car_puzzle_app/services/game_state.dart';
import 'package:car_puzzle_app/services/puzzle_service.dart';
import 'package:car_puzzle_app/services/stats_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PuzzleService()),
        ChangeNotifierProvider(
          create: (_) => StatsService()..init(),
        ),
        ChangeNotifierProvider(create: (_) => GameState()),
      ],
      child: MaterialApp(
        title: 'Car Puzzle App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const MainNavigator(),
        onGenerateRoute: (settings) {
          if (settings.name == '/puzzle') {
            final puzzle = settings.arguments as Puzzle;
            return MaterialPageRoute(
              builder: (context) => const PuzzleScreen(),
              settings: RouteSettings(arguments: puzzle),
            );
          }
          if (settings.name == '/dashboard') {
            return MaterialPageRoute(
              builder: (context) => const DashboardScreen(),
            );
          }
          return null;
        },
      ),
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const HomeScreen(),
    const DashboardScreen(),
    // Placeholder for the "My Game" screen, we won't navigate to it directly this way.
    Container(),
  ];

  void _onItemTapped(int index) {
    final gameState = Provider.of<GameState>(context, listen: false);
    if (index == 2) { // "My Game" tab
      if (gameState.activePuzzle != null) {
        Navigator.pushNamed(context, '/puzzle', arguments: gameState.activePuzzle).then((result) {
          // If user navigated to dashboard from puzzle screen, switch to dashboard tab
          if (result == 'dashboard') {
            setState(() {
              _selectedIndex = 1;
            });
          }
        });
      }
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for navigation changes from GameState
    final gameState = Provider.of<GameState>(context);
    if (gameState.pendingNavigation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePendingNavigation(gameState.pendingNavigation!);
        gameState.clearPendingNavigation();
      });
    }
  }

  void _handlePendingNavigation(String navigation) {
    switch (navigation) {
      case 'dashboard':
        setState(() {
          _selectedIndex = 1;
        });
        break;
      case 'home':
        setState(() {
          _selectedIndex = 0;
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    final bool isGameActive = gameState.activePuzzle != null;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
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
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        onTap: _onItemTapped,
        // Prevent selection of the disabled "My Game" tab
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
