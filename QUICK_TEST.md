# Quick API Test Guide

## ✅ Easiest Way to Test

**Just press F5 in Godot!** The API is already set up and will work automatically.

## 🧪 Manual Test (If you want to see detailed output)

### Option 1: Use the Test Script

1. **Create a simple test scene:**
   - In Godot: `Scene → New Scene`
   - Add a `Node` (not Node2D)
   - Attach script: `scripts/test_api_simple.gd`
   - Save as `scenes/APITest.tscn`

2. **Run it:**
   - Select the scene in FileSystem
   - Press **F6** (Play Scene)
   - Check Output panel

### Option 2: Test from Main Menu

The API manager is already set up as an autoload. When you run the main menu (F5), it will:
- Initialize the API manager
- Show API key status
- Be ready to generate riddles

To test it manually from code, add this to any script:

```gdscript
# Wait for APIManager to be ready
await get_tree().process_frame

# Test riddle generation
APIManager.riddle_generated.connect(func(riddle): print("Got riddle: ", riddle))
APIManager.generate_riddle(true)  # true = force API call
```

## 🔍 What to Look For

When you run the game (F5), check the **Output** panel at the bottom:

**Good signs:**
```
API MANAGER INITIALIZATION
API Key Status: FOUND
API Manager initialized. API Key configured: true
```

**If you see errors:**
- "API Key Status: NOT FOUND" → Check project.godot has the key
- "Cannot connect" → Check internet connection
- "HTTP Error 401" → API key might be invalid

## 🚀 Recommended: Just Run It!

**Press F5** - everything is already set up! The API will work when you call `APIManager.generate_riddle()` from your game code.
