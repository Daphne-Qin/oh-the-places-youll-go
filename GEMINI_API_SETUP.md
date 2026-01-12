# Gemini API Setup Guide

## Step 1: Get a Free Gemini API Key

1. **Visit Google AI Studio**: https://aistudio.google.com/app/apikey
2. **Sign in** with your Google account (free)
3. **Click "Create API Key"**
4. **Copy your API key** (it will look like: `AIzaSy...`)

**Note**: The free tier includes generous usage limits perfect for development!

## Step 2: Configure API Key in Godot

### Option A: Project Settings (Recommended)

1. Open your project in Godot
2. Go to **Project > Project Settings**
3. Click **Application > Config**
4. Click the **"+"** button to add a new property
5. Enter:
   - **Name**: `api/gemini_api_key`
   - **Type**: String
   - **Value**: Paste your API key
6. Click **OK**

### Option B: Environment Variable (Alternative)

**On macOS/Linux:**
```bash
export GEMINI_API_KEY="your_api_key_here"
```

**On Windows (Command Prompt):**
```cmd
set GEMINI_API_KEY=your_api_key_here
```

**On Windows (PowerShell):**
```powershell
$env:GEMINI_API_KEY="your_api_key_here"
```

## Step 3: Verify Setup

1. Run your game
2. Check the Godot console output
3. You should see: `API Manager initialized. API Key configured: true`

## Step 4: Using the API Manager

The `APIManager` is now available as a global singleton. Use it like this:

```gdscript
# Generate a riddle
APIManager.riddle_generated.connect(_on_riddle_received)
APIManager.riddle_generation_failed.connect(_on_riddle_failed)
APIManager.generate_riddle()

func _on_riddle_received(riddle_text: String):
    print("Riddle: ", riddle_text)

func _on_riddle_failed(error: String):
    print("Error: ", error)

# Validate an answer
APIManager.answer_validated.connect(_on_answer_validated)
APIManager.validate_answer("What am I?", "tree")

func _on_answer_validated(result: String):
    if result == "CORRECT":
        print("Correct!")
    else:
        print(result)  # "INCORRECT: [hint]"
```

## Features

- ✅ **Secure API key storage** (not hardcoded)
- ✅ **Rate limiting** (prevents API spam)
- ✅ **Error handling** (graceful fallbacks)
- ✅ **Offline support** (uses local JSON if API fails)
- ✅ **Timeout protection** (10 second limit)

## Troubleshooting

**"No API key found"**
- Check that you've added the key to Project Settings or environment variable
- Restart Godot after adding the key

**"Cannot connect to server"**
- Check your internet connection
- Verify the API key is correct
- Check if you've exceeded rate limits

**"Rate limit" messages**
- Wait 1 second between requests
- The system automatically prevents rapid requests

## API Usage Limits (Free Tier)

- **60 requests per minute**
- **1,500 requests per day**
- Perfect for game development and testing!
