# Riddle Caching System - Complete Guide

## Overview

The riddle caching system minimizes API costs by storing pre-generated riddles locally and only calling the Gemini API when necessary.

## How It Works

### 1. **Cache-First Strategy**
   - When `APIManager.generate_riddle()` is called, it first checks the cache
   - If cache has riddles available, it returns one randomly (without API call)
   - Only calls API if cache is empty or `force_api=true`

### 2. **Cache Management**
   - Loads 10 pre-generated riddles from `resources/riddle_cache.json` on startup
   - Tracks which riddles have been used to avoid immediate repeats
   - Resets usage tracking when all riddles have been used

### 3. **API Fallback**
   - If cache is empty → calls API
   - If player requests "new riddle" → calls API (stretch goal)
   - If API fails → uses fallback riddles from `fallback_riddles.json`

## File Structure

```
resources/
  ├── riddle_cache.json      # 10 pre-generated medium-hard riddles
  └── fallback_riddles.json  # Emergency fallback riddles
```

## Cache JSON Format

```json
{
  "riddles": [
    {
      "riddle": "I turn sunlight into food...",
      "answer": "tree"
    },
    ...
  ]
}
```

## Usage Examples

### Basic Usage (Uses Cache)
```gdscript
# This will use cache first, no API call
APIManager.riddle_generated.connect(_on_riddle_received)
APIManager.generate_riddle()

func _on_riddle_received(riddle_text: String):
    print("Riddle: ", riddle_text)
```

### Force API Call (New Riddle)
```gdscript
# This will skip cache and call API directly
APIManager.generate_riddle(force_api=true)
```

### Check Cache Status
```gdscript
# The API manager automatically logs cache status on startup
# Check console: "Riddle cache loaded: 10 riddles available"
```

## Pre-Generating Riddles

### Method 1: Editor Script (Recommended)
1. Open Godot Editor
2. Go to **Tools > Execute Script**
3. Select `scripts/pre_generate_riddles.gd`
4. Wait for 10 riddles to be generated (~15-20 seconds)
5. Check `resources/riddle_cache.json` for results

### Method 2: Standalone Scene
1. Create a new scene with a Node
2. Attach `scripts/pre_generate_riddles_standalone.gd` to the node
3. Run the scene (F6)
4. Check console output and `resources/riddle_cache.json`

### What the Script Does
- Calls Gemini API 10 times
- Waits 1.5 seconds between requests (rate limiting)
- Extracts answers from riddle text (basic heuristic)
- Saves all riddles to `riddle_cache.json`

## Cost Savings

### Without Cache:
- Every riddle request = 1 API call
- 100 players = 100 API calls
- Cost: ~$0.01 per 1000 requests

### With Cache:
- First 10 requests = 0 API calls (uses cache)
- Only calls API if cache exhausted or force_api=true
- 100 players using cache = 0 API calls
- **100% cost reduction for cached riddles!**

## Cache Behavior

### Normal Flow:
1. Player requests riddle → Cache used (no API call)
2. Player requests another → Cache used (different riddle)
3. After 10 riddles used → Cache resets, starts over
4. API never called unless cache is empty

### Force API Flow:
1. Player clicks "New Riddle" button
2. `generate_riddle(force_api=true)` called
3. API called directly (bypasses cache)
4. New riddle returned

## Updating the Cache

### Option 1: Use Pre-Generation Script
- Run the pre-generation script to get fresh riddles
- Replaces entire cache with 10 new riddles

### Option 2: Manual Edit
- Open `resources/riddle_cache.json`
- Add/edit riddles manually
- Follow the JSON format

### Option 3: Runtime Addition (Future)
- Currently disabled to keep cache static
- Can be enabled by uncommenting `_add_to_cache()` in API manager
- Would allow cache to grow over time

## Troubleshooting

### "Riddle cache loaded: 0 riddles available"
- Check that `riddle_cache.json` exists
- Verify JSON format is correct
- Run pre-generation script to create cache

### "Using cached riddle (API call saved!)"
- This is good! Cache is working
- No API call was made
- Cost saved

### Cache Not Working
- Check console for cache load messages
- Verify `riddle_cache.json` has valid JSON
- Ensure file is in `resources/` folder

## Best Practices

1. **Pre-generate during development**: Run the script once to populate cache
2. **Use cache for normal gameplay**: Only force API for special "new riddle" feature
3. **Update cache periodically**: Re-run script to get fresh riddles
4. **Monitor API usage**: Check console logs to see when API is called

## API Manager Changes

The `APIManager` now includes:
- `generate_riddle(force_api=false)` - Uses cache by default
- `_load_riddle_cache()` - Loads cache on startup
- `_get_cached_riddle()` - Returns random unused riddle
- `_add_to_cache()` - Adds new riddle to cache (optional)

## Summary

✅ **10 pre-generated riddles** stored in JSON  
✅ **Cache-first strategy** minimizes API calls  
✅ **Force API option** for "new riddle" feature  
✅ **Pre-generation script** for easy cache updates  
✅ **Automatic fallback** if cache is empty  
✅ **Usage tracking** prevents immediate repeats  

The caching system is fully integrated and ready to use!
