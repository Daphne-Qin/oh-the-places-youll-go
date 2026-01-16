# API Testing Guide

## 🚀 Easiest Ways to Test the API

### Option 1: Run in Godot Editor (Easiest)

1. **Open Godot Editor**
   - Double-click `project.godot` or open it in Godot
   
2. **Run the Game**
   - Press **F5** (or click the Play button ▶️)
   - The game will start and automatically run the API test on startup
   
3. **Check the Output Panel**
   - Look at the bottom of the Godot editor
   - Click on the **Output** tab
   - You'll see all the API test print statements

**What you'll see:**
```
==================================================
API MANAGER INITIALIZATION
==================================================
[API KEY CHECK] Checking for API key...
API Key Status: FOUND
...
==================================================
RUNNING STARTUP API TEST
==================================================
[TEST] Testing riddle generation...
[API CALL] Making HTTP POST request...
[API RESPONSE] SUCCESS! Riddle received: [riddle text]
```

---

### Option 2: Test Script (Without Full Game)

1. **Create a Test Scene**
   - In Godot: Scene → New Scene
   - Add a Node (not Node2D, just Node)
   - Attach the script: `scripts/test_api_simple.gd`
   - Save the scene as `scenes/APITest.tscn`

2. **Run the Test Scene**
   - Select the scene in the FileSystem
   - Press **F6** (or click Play Scene button)
   - Check the Output panel for results

---

### Option 3: Command Line Test (Advanced)

If you have Godot installed and in your PATH:

```bash
cd /Users/riyaseth/460/oh-the-places-youll-go
./test_api.sh
```

Or directly:
```bash
godot --headless --script scripts/test_api_standalone.gd
```

---

## 📋 What the Tests Check

✅ **API Key Configuration**
- Verifies the key is loaded from project settings
- Shows first 10 characters (for verification)

✅ **HTTP Request**
- Tests connection to Gemini API
- Shows request URL and body

✅ **API Response**
- Checks HTTP status code (should be 200)
- Parses JSON response
- Extracts riddle text

✅ **Error Handling**
- Shows detailed error messages if something fails
- Falls back to local riddles if API fails

---

## 🐛 Troubleshooting

### "API Key not found"
- Check `project.godot` has: `config/api/gemini_api_key="..."`
- Restart Godot after adding the key

### "Cannot connect to server"
- Check your internet connection
- Verify the API key is valid
- Check if Gemini API is accessible

### "HTTP Error 400/401"
- API key might be invalid
- Check the key in project settings

### "HTTP Error 429"
- Rate limit exceeded
- Wait a minute and try again

---

## 💡 Quick Test from Code

You can also test directly from any script:

```gdscript
# In any script, after APIManager is initialized:
APIManager.riddle_generated.connect(func(riddle): print("Got riddle: ", riddle))
APIManager.generate_riddle(true)  # true = force API call
```

---

## ✅ Expected Output

**Success:**
```
[API RESPONSE] HTTP Response code: 200
[API RESPONSE] Parsed JSON successfully
[RESPONSE] SUCCESS!
[RESPONSE] Riddle received: I clean the air you breathe...
```

**Failure:**
```
[API RESPONSE] ERROR: HTTP Error 401
[API RESPONSE] Response body: {"error": {"message": "API key not valid"}}
```

---

## 🎯 Recommended: Use Option 1

**Just press F5 in Godot** - it's the easiest and shows everything in the Output panel!
