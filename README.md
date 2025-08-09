# 🧩 Car Puzzle App

An interactive Flutter puzzle game featuring beautiful car-themed jigsaw puzzles with advanced gameplay mechanics and intuitive touch controls.

## 📱 Features

### 🎮 Core Gameplay
- **Drag & Drop Mechanics**: Intuitive piece placement with automatic snapping
- **Smart Anchor System**: Designated anchor pieces (green-tinted) for moving entire puzzle groups
- **Dynamic Piece Positioning**: Alternating left/right placement for better visibility
- **Ghost Preview**: Long-press active pieces to see placement hints
- **Piece Selection**: Manual piece selection through FAB long-press drawer

### 🎯 Advanced Controls
- **Pinch-to-Zoom**: Scale puzzles by pinching the anchor piece (10%-100%)
- **Precision Scaling**: Slider control for exact size adjustments
- **Anchor Switching**: Double-tap or long-press any placed piece to make it the new anchor
- **Smart Repositioning**: FAB tap repositions active pieces for better access
- **Visual Feedback**: Real-time size indicators and anchor change notifications

### 💾 State Management
- **Progress Persistence**: Game state saved automatically across app sessions
- **Navigation Continuity**: Puzzle progress maintained when switching screens
- **Smart Recovery**: Resume puzzles exactly where you left off

### 🎨 User Experience
- **Beautiful Gradients**: Eye-catching purple-pink-orange background
- **Responsive Design**: Optimized for various screen sizes
- **Minimal Margins**: Maximum canvas area for puzzle gameplay
- **Search & Filter**: Find puzzles by name, description, or tags
- **Completion Tracking**: Timer and piece counter with completion celebration

## 🏗️ Architecture

### Tech Stack
- **Framework**: Flutter 3.x
- **State Management**: Provider pattern
- **HTTP Client**: http package for API communication
- **Local Storage**: SharedPreferences for game state persistence
- **UI Components**: Material Design with custom gradients
- **Image Handling**: Network images with caching

### Key Services
- **PuzzleService**: Fetches puzzle data and piece information from CDN
- **GameState**: Manages puzzle progress, anchor state, and navigation
- **StatsService**: Tracks completion times and game statistics

### Data Models
- **Puzzle**: Metadata including name, description, difficulty, tags
- **PuzzlePiece**: Individual piece data with bounds, paths, and placement state
- **PuzzleData**: Complete puzzle information with spatial relationships

## 🎮 How to Play

### Getting Started
1. **Browse Puzzles**: Search and filter available puzzles by tags
2. **Start Game**: Tap "Start" on any ready puzzle (shows piece count)
3. **Anchor Placement**: The first piece (g0) automatically becomes the anchor

### Basic Controls
- **Drag Pieces**: Move active pieces around the canvas
- **Snap to Place**: Drag pieces near their correct position to auto-snap
- **Get Next Piece**: Tap FAB to get the next piece in sequence
- **Select Specific Piece**: Long-press FAB to open piece selection drawer

### Advanced Techniques
- **Resize Puzzle**: Pinch the green anchor piece to zoom in/out
- **Precise Sizing**: Use the tune button for exact size control
- **Change Anchor**: Double-tap any placed piece to make it the new anchor
- **Reposition Active Piece**: Tap FAB when a piece is already active
- **View Hints**: Long-press active pieces to see ghost placement preview

### Visual Indicators
- **🟢 Green Tint**: Current anchor piece (draggable, scalable)
- **🔵 Blue Border**: Placed pieces (tappable to become anchor)
- **⚪ No Border**: Active piece being positioned
- **👻 Dotted Ghost**: Placement hint during long-press

## 🔧 Installation & Setup

### Prerequisites
- Flutter SDK 3.0.0 or higher
- Dart SDK
- Android Studio / VS Code with Flutter extensions

### Dependencies
```yaml
dependencies:
  flutter: sdk: flutter
  provider: ^6.0.0
  http: ^1.2.1
  google_fonts: ^6.2.1
  flutter_svg: ^2.0.10+1
  dotted_border: ^2.1.0
  shared_preferences: ^2.0.15
```

### Quick Start
```bash
# Clone the repository
git clone <repository-url>
cd car-puzzle-app

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Building for Production
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (requires macOS)
flutter build ios --release
```

## 🌐 API Integration

### Puzzle Data Sources
- **Puzzle Metadata**: `https://puzzle-manager.agility-maint.net/puzzles`
- **Asset CDN**: `https://puzzle-assets.agility-maint.net`
- **Fallback CDN**: `https://pub-0190997ca1814eaf8cb0bffd73e7abb2.r2.dev`

### Data Format
Puzzles include SVG images, individual piece PNGs, thumbnails, and dimension files for precise piece positioning.

## 🎯 Game Mechanics

### Piece Management
1. **Anchor System**: One piece serves as the reference point for all others
2. **Relative Positioning**: All pieces maintain their relationship to the anchor
3. **Smart Placement**: Pieces alternate between left and right sides for visibility
4. **Snap Detection**: 25-pixel threshold for automatic piece placement

### Scaling System
- **Pinch Gesture**: Natural two-finger scaling on anchor piece
- **Slider Control**: Precise percentage-based sizing (10%-100%)
- **Real-time Feedback**: Live scale percentage display
- **Constraint Handling**: Prevents extreme sizes that break gameplay

### State Persistence
- **Game Progress**: Placed pieces, anchor state, elapsed time
- **Navigation State**: Maintains progress across screen changes
- **Session Recovery**: Automatic restoration on app restart

## 🚀 Performance Features

### Optimization Strategies
- **Image Caching**: Network images cached for smooth gameplay
- **State Efficiency**: Minimal rebuilds with targeted setState calls
- **Memory Management**: Proper disposal of timers and controllers
- **Gesture Optimization**: Efficient touch handling for responsive controls

### Platform Considerations
- **Android**: Optimized gesture detection for touch devices
- **iOS**: Native scrolling and pinch behaviors
- **Web**: Fallback controls for mouse-based interaction

## 🎨 UI/UX Design

### Visual Hierarchy
- **App Bar**: Puzzle info, controls, progress indicators
- **Canvas**: Maximum area with minimal margins for gameplay
- **FAB**: Primary action button with gesture-based secondary functions
- **Bottom Navigation**: Easy switching between game sections

### Color Scheme
- **Background**: Purple-pink-orange gradient for visual appeal
- **Canvas**: Clean white background for puzzle focus
- **Anchor**: Green tint for clear identification
- **UI Elements**: Blue accents for interactive components

### Accessibility
- **Touch Targets**: Appropriately sized for finger interaction
- **Visual Feedback**: Clear indicators for all interactive elements
- **Error Handling**: Graceful degradation for network issues

## 🔄 Development Workflow

### Project Structure
```
lib/
├── main.dart                 # App entry point
├── models/
│   └── puzzle.dart          # Data models
├── screens/
│   ├── home_screen.dart     # Puzzle browser
│   └── puzzle_screen.dart   # Main game interface
└── services/
    ├── puzzle_service.dart  # API communication
    ├── game_state.dart      # State management
    └── stats_service.dart   # Progress tracking
```

### Key Implementation Details
- **Route Management**: Named routes with argument passing
- **Provider Pattern**: Dependency injection for services
- **Lifecycle Handling**: Proper state saving on app pause/resume
- **Error Boundaries**: Graceful handling of network and parsing errors

## 📈 Future Enhancements

### Planned Features
- **Multiple Puzzle Types**: Beyond car themes
- **Difficulty Levels**: Varying piece counts and complexity
- **Social Features**: Share completed puzzles
- **Offline Mode**: Local puzzle storage
- **Custom Puzzles**: User-uploaded images

### Performance Improvements
- **Progressive Loading**: Stream puzzle pieces as needed
- **Background Processing**: Pre-cache upcoming pieces
- **Enhanced Caching**: Smarter asset management

## 🤝 Contributing

### Development Guidelines
1. Follow Flutter best practices and style guidelines
2. Maintain backward compatibility with existing save states
3. Test on multiple devices and screen sizes
4. Document new features and API changes

### Code Style
- Use meaningful variable names
- Comment complex game logic
- Follow Dart naming conventions
- Maintain consistent indentation

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues, feature requests, or questions:
1. Check existing issues in the repository
2. Create detailed bug reports with reproduction steps
3. Include device information and Flutter version
4. Provide screenshots or videos for UI issues

---

**Built with ❤️ using Flutter**

*Experience the joy of puzzle-solving with intuitive touch controls and beautiful car-themed designs!*
