# oh-the-places-youll-go
Oh the Places You'll Go

A Godot 4 game project based on Dr. Seuss's "The Lorax".

## Getting Started

### Installing Godot 4

**Option 1: Download from Official Website (Recommended)**
1. Visit [https://godotengine.org/download](https://godotengine.org/download)
2. Download Godot 4.3 or later for macOS
3. Extract the `.zip` file
4. Move `Godot.app` to your Applications folder (optional)

**Option 2: Install via Homebrew**
```bash
brew install --cask godot
```

### Running the Game

**Method 1: Using Godot Editor (Recommended for Development)**
1. Open Godot
2. Click "Import" button
3. Navigate to this project folder and select `project.godot`
4. Click "Import & Edit"
5. Press `F5` or click the "Play" button (▶️) in the top-right corner

**Method 2: Using Command Line**
If Godot is in your PATH:
```bash
godot --path . --main-pack scenes/MainMenu.tscn
```

Or if Godot is in Applications:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --main-pack scenes/MainMenu.tscn
```

### Project Structure

- `/scenes` - Game scenes (MainMenu, LoraxLevel, EndScreen)
- `/scripts` - GDScript files (player movement, dialogue, API, cutscenes)
- `/assets` - Sprites, audio, and fonts
- `/resources` - JSON data files (dialogue, riddle cache)

### Controls

- **Arrow Keys** or **WASD** - Move player left/right
- Movement is automatically disabled during cutscenes and dialogue
