
# 🧩 Puzzle Game – App Spec & JS Integration Notes

## Overview

This puzzle game involves drag-and-drop interaction with SVG parts. Users complete puzzles by dragging individual parts into their correct positions over an SVG outline. On completion, animations and achievements are shown. The app includes puzzle tracking, timing, and suggested puzzles based on history.

---

## 1. App Requirements

### ✅ Core Features

- Load a puzzle from local or remote JSON (title, description, imgUrl, emoji, pieces, difficulty, tags)
- JSON link is at https://azuprddatasave.blob.core.windows.net/minigames/cars.js?t={timestamp}; timestamp is to avoid caching
- {
    "name": "Kia Soul 4D Hatchback",
    "desc": "Boxy car with four doors that looks like a fun little robot on wheels!",
    "pieces": 18,
    "level": "Easy",
    "tags": "easy,cars",
    "img": "https://azuprddatasave.blob.core.windows.net/minigames/079I0049x.svg"
  }
- Load an SVG outline with draggable parts rendered over it
- Track puzzle progress and completion time
- Detect correct placement by comparing thumb position to part target center
- Animate correct drop and completion with pulse/shimmer and message overlay
- Provide reset option to replay puzzle
- Store completed puzzles and times locally
- Show recommended puzzles (based on incomplete/completed stats)

### 🎮 Game Flow

1. **Load Puzzle Metadata** (title, image, description)
2. **Load Puzzle SVG**
   - Display outline image (`puzzleSvg`)
   - Add invisible hitboxes (`rt1`, `rt2`, ...) to thumb tray
   - Clone and drag part targets (`g1`, `g2`, ...)
3. **Drag and Drop Interaction**
   - On mouse/touch start: clone group `g#`
   - Follow pointer until released
   - Check distance between dropped position and target center
   - If within threshold → snap, show success, hide original
   - If incorrect → animate back to tray
4. **Completion**
   - Animate outline SVG with pulse and opacity
   - Show floating success message
   - Save completion time to local storage

### 🎨 Visuals

- Responsive SVG layout
- Transparent hitboxes and draggable elements
- Emoji fallback if SVG fails
- Gradient backgrounds and blurred card effects
- Celebration badges and modal overlays on success

### 🕹️ Interaction

- Timer starts on puzzle load
- Puzzle resets on command
- Game state: `playing` / `completed`
- Mobile + desktop input support (mouse & touch)
- Reacts to missing or invalid puzzle IDs with fallback screens

### 🧠 Puzzle Completion Tracking

- Store puzzle ID and completion time in `localStorage`
- Track `completedPuzzles` array and `puzzleTimes` map
- Recommended puzzles prioritize incomplete ones, randomly shuffled

---

## 2. Technical Implementation (JS/React Notes)

### 🔁 SVG Injection and Cleanup

- SVG is fetched via `fetch(puzzle.imgUrl)`
- Injected into a container via `innerHTML = svgText`
- Dimensions are stripped (`width`, `height`), and viewBox is added if missing
- Styles applied: `width: 100%`, `height: auto`, `maxHeight: 80vh`

### 🧩 Puzzle Parts Setup

- Target parts: SVG groups `g1`, `g2`, `g3`, ... (hidden initially)
- Thumbs: groups `t1`, `t2`, ... with invisible rectangles (`rt1`, `rt2`, ...) over them
- `rt#` hitboxes are clickable/drag sources
- Part target center positions are computed via `.bbox()`

### ✋ Drag & Drop Logic

- On `mousedown` / `touchstart` on `rt#`, a clone of `g#` is created
- The clone follows the pointer using `mousemove` / `touchmove`
- On release:
  - Distance to correct target center is measured
  - If close enough (e.g. `dist < 50`), the target is shown and floating part is removed
  - The thumb group is hidden
  - If incorrect, floating clone animates back to tray and is removed

### 🏁 Completion Logic

- Puzzle is considered complete when all `rt#` thumb parents are hidden
- Animation runs on the outline (`#puzzleSvg`) with `.animate().scale().opacity().loop()`
- Random celebration text is added using `svgInstance.text()`
- Completion time is calculated via `Date.now() - startTimeRef.current`
- Stats are saved with `savePuzzleCompletion(puzzleId, time, seconds)`

### 💡 Helpers

- `getDynamicGroupCount()`: counts elements with ID prefix `g#`
- `getSVGCoordsFromEvent()`: converts mouse/touch coordinates into SVG coordinates using `.point(x, y)`

---

## 3. UI Elements

- **Timer & Reset:** Top right of puzzle screen
- **Puzzle Info:** Title, emoji, badges (difficulty, piece count)
- **SVG Puzzle Area:** Main puzzle canvas
- **Recommended Puzzles:** 4 cards rendered below the puzzle
- **Completion Modal:** Appears after finishing puzzle

---

## 4. Animation & UX Polish

- Floating thumbs use `.opacity(0.4)` and `.center()`
- Wrong drops animate back to tray using `.animate(300).center(...)`
- Success uses `.show()`, `.hide()` on appropriate parts
- SVG outline pulse uses `.loop(3)` and `.scale(0.95).opacity(0.9)`
- Celebration text animates with `.fill(color).font().move().animate()`

---

## 5. Development Notes

- Uses `@svgdotjs/svg.js` for SVG manipulation
- All element access by ID: `#g1`, `#rt1`, `#t1`, etc.
- Local state stored with `localStorage`
- React hooks (`useState`, `useEffect`, `useRef`) used for state + timers
- All assets should be preprocessed to follow ID naming convention

---

## ✅ Summary

This document provides a complete breakdown of the current implementation of the SVG puzzle game logic written in React and JS using SVG.js. Flutter developers should reference these behaviors and flow while porting to native widgets. Matching interactive fidelity will require careful layout and hit-testing logic in Flutter.

---
