extends EditorScript

## Development Tool: Pre-Generate Riddles
## 
## This script generates 10 riddles from the Gemini API and saves them to riddle_cache.json
## 
## HOW TO USE:
## 1. Make sure your API key is configured in Project Settings
## 2. In Godot Editor: Tools > Execute Script
## 3. Select this file: scripts/pre_generate_riddles.gd
## 4. Wait for all 10 riddles to be generated
## 5. Check resources/riddle_cache.json for the results

const CACHE_FILE_PATH = "res://resources/riddle_cache.json"
const NUM_RIDDLES = 10
const GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key="

var generated_riddles: Array[Dictionary] = []
var current_request_index: int = 0
var http_request: HTTPRequest

func _run() -> void:
	print("==================================================")
	print("RIDDLE PRE-GENERATION TOOL")
	print("==================================================")
	
	# Check for API key
	var api_key = _get_api_key()
	if api_key == "":
		print("ERROR: No API key found!")
		print("Please configure your API key in Project Settings:")
		print("  Project > Project Settings > Application > Config")
		print("  Add property: api/gemini_api_key")
		return
	
	print("API Key found. Starting generation of ", NUM_RIDDLES, " riddles...")
	print("This may take a minute. Please wait...")
	print("")
	
	# Create HTTPRequest
	http_request = HTTPRequest.new()
	get_editor_interface().get_script_editor().add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	http_request.timeout = 15.0
	
	# Start generating riddles
	_generate_next_riddle()

func _get_api_key() -> String:
	"""Get API key from project settings or environment variable."""
	# Try project settings first
	if ProjectSettings.has_setting("api/gemini_api_key"):
		var key = ProjectSettings.get_setting("api/gemini_api_key")
		if key != null and key != "":
			return str(key)
	
	# Fallback to environment variable
	var env_key = OS.get_environment("GEMINI_API_KEY")
	if env_key != null and env_key != "":
		return env_key
	
	return ""

func _generate_next_riddle() -> void:
	"""Generate the next riddle in the sequence."""
	if current_request_index >= NUM_RIDDLES:
		# All riddles generated, save to file
		_save_riddles_to_cache()
		return
	
	current_request_index += 1
	print("Generating riddle ", current_request_index, " of ", NUM_RIDDLES, "...")
	
	var api_key = _get_api_key()
	var url = GEMINI_API_URL + api_key
	
	# Create the request payload
	var prompt = "Generate a single riddle for 12-year-old students about why forests and trees are important for the environment. The answer should be 1-2 words. Only return the riddle text, no extra commentary."
	
	var request_body = {
		"contents": [{
			"parts": [{
				"text": prompt
			}]
		}]
	}
	
	var json_body = JSON.stringify(request_body)
	var headers = ["Content-Type: application/json"]
	
	# Make the HTTP request
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	
	if error != OK:
		print("ERROR: Failed to start request: ", error)
		_generate_next_riddle()  # Skip this one and continue
		return
	
	# Wait a bit to avoid rate limiting
	await get_tree().create_timer(1.5).timeout

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Handle HTTP request completion."""
	if result != HTTPRequest.RESULT_SUCCESS:
		print("ERROR: Request failed with result code: ", result)
		_generate_next_riddle()  # Continue with next
		return
	
	if response_code != 200:
		print("ERROR: HTTP Error ", response_code)
		_generate_next_riddle()  # Continue with next
		return
	
	# Parse JSON response
	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())
	
	if parse_error != OK:
		print("ERROR: Failed to parse API response")
		_generate_next_riddle()  # Continue with next
		return
	
	var response_data = json.data
	
	# Extract text from Gemini API response
	var response_text = ""
	if response_data.has("candidates") and response_data["candidates"].size() > 0:
		var candidate = response_data["candidates"][0]
		if candidate.has("content") and candidate["content"].has("parts"):
			var parts = candidate["content"]["parts"]
			if parts.size() > 0 and parts[0].has("text"):
				response_text = parts[0]["text"].strip_edges()
	
	if response_text == "":
		print("ERROR: Empty response from API")
		_generate_next_riddle()  # Continue with next
		return
	
	# Extract answer (basic heuristic)
	var answer = _extract_answer_from_riddle(response_text)
	
	var riddle_data = {
		"riddle": response_text,
		"answer": answer
	}
	
	generated_riddles.append(riddle_data)
	print("✓ Riddle ", current_request_index, " generated: ", response_text)
	
	# Wait before next request (rate limiting)
	await get_tree().create_timer(1.5).timeout
	
	# Generate next riddle
	_generate_next_riddle()

func _extract_answer_from_riddle(riddle_text: String) -> String:
	"""Extract answer from riddle text (basic heuristic)."""
	var lower_text = riddle_text.to_lower()
	
	# Check for common keywords
	if "forest" in lower_text or "forests" in lower_text:
		return "forest"
	elif "tree" in lower_text or "trees" in lower_text:
		return "tree"
	
	# Default to tree
	return "tree"

func _save_riddles_to_cache() -> void:
	"""Save generated riddles to cache JSON file."""
	if generated_riddles.size() == 0:
		print("ERROR: No riddles generated!")
		return
	
	var data = {
		"riddles": generated_riddles
	}
	
	var json_string = JSON.stringify(data, "\t")
	
	# Save to file
	var file = FileAccess.open(CACHE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		print("ERROR: Could not open cache file for writing: ", CACHE_FILE_PATH)
		return
	
	file.store_string(json_string)
	file.close()
	
	print("")
	print("==================================================")
	print("SUCCESS!")
	print("==================================================")
	print("Generated ", generated_riddles.size(), " riddles")
	print("Saved to: ", CACHE_FILE_PATH)
	print("")
	print("You can now use these cached riddles in your game!")
	print("The API will only be called if the cache is empty or")
	print("the player requests a 'new riddle' (force_api=true).")
	print("==================================================")
	
	# Cleanup
	if http_request:
		http_request.queue_free()
