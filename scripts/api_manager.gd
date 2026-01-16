extends Node

## Gemini API Manager (Autoload Singleton)
## Handles all API interactions with Google's Gemini API for riddle generation and validation
##
## SETUP INSTRUCTIONS:
## 1. Get a free Gemini API key from: https://aistudio.google.com/app/apikey
## 2. In Godot: Project > Project Settings > Application > Config > Add Property
##    - Name: "api/gemini_api_key"
##    - Type: String
##    - Value: Your API key
## 3. OR set environment variable: export GEMINI_API_KEY="your_key_here"

# Gemini API Configuration
const GEMINI_API_URL: String = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key="
const REQUEST_TIMEOUT: float = 10.0  # 10 seconds timeout
const RATE_LIMIT_DELAY: float = 1.0  # Minimum 1 second between requests

# Rate limiting
var last_request_time: float = 0.0
var is_requesting: bool = false

# HTTPRequest node (reused for all requests)
var http_request: HTTPRequest

# Fallback riddles loaded from local JSON
var fallback_riddles: Array[Dictionary] = []

# Riddle cache system (to minimize API costs)
var riddle_cache: Array[Dictionary] = []
var used_riddles: Array[int] = []  # Track indices of used riddles
var cache_file_path: String = "res://resources/riddle_cache.json"

# Signals
signal riddle_generated(riddle_text: String)
signal riddle_generation_failed(error_message: String)
signal answer_validated(result: String)  # "CORRECT" or "INCORRECT: [hint]"
signal answer_validation_failed(error_message: String)

func _ready() -> void:
	"""Initialize the API manager."""
	# Create HTTPRequest node
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	http_request.timeout = REQUEST_TIMEOUT  # Set 10 second timeout
	
	# Load fallback riddles from local JSON
	_load_fallback_riddles()
	
	# Load riddle cache from JSON
	_load_riddle_cache()
	
	print("API Manager initialized. API Key configured: ", _has_api_key())
	print("Riddle cache loaded: ", riddle_cache.size(), " riddles available")

func _has_api_key() -> bool:
	"""Check if API key is configured."""
	var api_key = _get_api_key()
	return api_key != "" and api_key != null

func _get_api_key() -> String:
	"""
	Get API key from project settings or environment variable.
	Priority: Project Settings > Environment Variable
	"""
	# Try project settings first
	if ProjectSettings.has_setting("api/gemini_api_key"):
		var key = ProjectSettings.get_setting("api/gemini_api_key")
		if key != null and key != "":
			return str(key)
	
	# Fallback to environment variable
	var env_key = OS.get_environment("GEMINI_API_KEY")
	if env_key != null and env_key != "":
		return env_key
	
	# Return empty string if not found
	return ""

func _check_rate_limit() -> bool:
	"""Check if enough time has passed since last request (rate limiting)."""
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last = current_time - last_request_time
	
	if time_since_last < RATE_LIMIT_DELAY:
		var wait_time = RATE_LIMIT_DELAY - time_since_last
		print("Rate limit: Waiting ", wait_time, " seconds before next request")
		return false
	
	return true

func _update_rate_limit() -> void:
	"""Update the last request time for rate limiting."""
	last_request_time = Time.get_ticks_msec() / 1000.0

func generate_riddle(force_api: bool = false) -> void:
	"""
	Generate a riddle using cache first, then API if needed.
	
	Args:
		force_api: If true, skip cache and call API directly (for "new riddle" requests)
	
	Emits: riddle_generated(riddle_text) or riddle_generation_failed(error_message)
	"""
	# If not forcing API, try cache first
	if not force_api:
		var cached_riddle = _get_cached_riddle()
		if cached_riddle != "":
			print("Using cached riddle (API call saved!)")
			riddle_generated.emit(cached_riddle)
			return
	
	# Cache is empty or force_api is true - call API
	_generate_riddle_from_api()

func _generate_riddle_from_api() -> void:
	"""Internal function to generate riddle from API."""
	# Check if already processing a request
	if is_requesting:
		riddle_generation_failed.emit("Another request is already in progress. Please wait.")
		return
	
	# Check rate limiting
	if not _check_rate_limit():
		riddle_generation_failed.emit("Please wait a moment before requesting another riddle.")
		return
	
	# Check API key
	if not _has_api_key():
		print("Warning: No API key found. Using fallback riddle.")
		_use_fallback_riddle()
		return
	
	is_requesting = true
	_update_rate_limit()
	
	# Prepare the API request
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
		is_requesting = false
		riddle_generation_failed.emit("Failed to start request: " + str(error))
		print("HTTP Request error: ", error)
		_use_fallback_riddle()

func validate_answer(riddle_text: String, player_answer: String) -> void:
	"""
	Validate a player's answer using Gemini API.
	
	Args:
		riddle_text: The riddle that was asked
		player_answer: The player's answer
	
	Emits: answer_validated(result) or answer_validation_failed(error_message)
	"""
	# Check if already processing a request
	if is_requesting:
		answer_validation_failed.emit("Another request is already in progress. Please wait.")
		return
	
	# Check rate limiting
	if not _check_rate_limit():
		answer_validation_failed.emit("Please wait a moment before validating again.")
		return
	
	# Check API key
	if not _has_api_key():
		print("Warning: No API key found. Using basic validation.")
		_basic_validation(riddle_text, player_answer)
		return
	
	is_requesting = true
	_update_rate_limit()
	
	# Prepare the API request
	var api_key = _get_api_key()
	var url = GEMINI_API_URL + api_key
	
	# Create the validation prompt
	var prompt = "Riddle: " + riddle_text + ". The player answered: " + player_answer + ". Is this correct? Respond with 'CORRECT' if right, or 'INCORRECT: [brief hint]' if wrong."
	
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
		is_requesting = false
		answer_validation_failed.emit("Failed to start request: " + str(error))
		print("HTTP Request error: ", error)
		_basic_validation(riddle_text, player_answer)

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Handle HTTP request completion."""
	is_requesting = false
	
	# Check for HTTP errors
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg = _get_error_message(result)
		riddle_generation_failed.emit(error_msg)
		answer_validation_failed.emit(error_msg)
		_use_fallback_riddle()
		return
	
	if response_code != 200:
		var error_msg = "HTTP Error: " + str(response_code)
		riddle_generation_failed.emit(error_msg)
		answer_validation_failed.emit(error_msg)
		_use_fallback_riddle()
		return
	
	# Parse JSON response
	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())
	
	if parse_error != OK:
		var error_msg = "Failed to parse API response"
		riddle_generation_failed.emit(error_msg)
		answer_validation_failed.emit(error_msg)
		_use_fallback_riddle()
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
		var error_msg = "Empty response from API"
		riddle_generation_failed.emit(error_msg)
		answer_validation_failed.emit(error_msg)
		_use_fallback_riddle()
		return
	
	# Determine if this was a riddle generation or validation request
	# (We'll track this with a simple flag or check the response format)
	if response_text.to_upper().begins_with("CORRECT") or response_text.to_upper().begins_with("INCORRECT"):
		# This is a validation response
		answer_validated.emit(response_text)
	else:
		# This is a riddle generation response
		# Optionally save to cache for future use (stretch goal)
		# _add_to_cache(response_text)
		riddle_generated.emit(response_text)

func _get_error_message(result: int) -> String:
	"""Convert HTTPRequest result code to human-readable error message."""
	match result:
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return "Network error: Data size mismatch"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Cannot connect to server. Check your internet connection."
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Cannot resolve server address. Check your internet connection."
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Connection error. Please try again."
		HTTPRequest.RESULT_NO_RESPONSE:
			return "No response from server. Request may have timed out."
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "Response too large"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "Request failed. Please try again."
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return "File error"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "File write error"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "Too many redirects"
		_:
			return "Unknown error: " + str(result)

func _load_fallback_riddles() -> void:
	"""Load fallback riddles from local JSON file."""
	var file_path = "res://resources/fallback_riddles.json"
	
	if not ResourceLoader.exists(file_path):
		print("Warning: Fallback riddles file not found. Creating default riddles.")
		_create_default_fallback_riddles()
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("Warning: Could not open fallback riddles file.")
		_create_default_fallback_riddles()
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_error = json.parse(json_string)
	
	if parse_error != OK:
		print("Warning: Could not parse fallback riddles JSON.")
		_create_default_fallback_riddles()
		return
	
	var data = json.data
	if data.has("riddles") and data["riddles"] is Array:
		pass
		#fallback_riddles = data["riddles"]
		#print("Loaded ", fallback_riddles.size(), " fallback riddles.")
	else:
		_create_default_fallback_riddles()

func _create_default_fallback_riddles() -> void:
	"""Create default fallback riddles if JSON file doesn't exist."""
	fallback_riddles = [
		{
			"riddle": "I clean the air you breathe, and give homes to many creatures. What am I?",
			"answer": "tree"
		},
		{
			"riddle": "I'm a home for birds and bugs, and I help stop floods. What am I?",
			"answer": "forest"
		},
		{
			"riddle": "I turn carbon dioxide into oxygen, making life possible. What am I?",
			"answer": "tree"
		},
		{
			"riddle": "I'm a natural air filter, standing tall and green. What am I?",
			"answer": "tree"
		},
		{
			"riddle": "I prevent soil from washing away and provide shade. What am I?",
			"answer": "tree"
		}
	]
	print("Using default fallback riddles.")

func _load_riddle_cache() -> void:
	"""Load riddle cache from JSON file."""
	if not ResourceLoader.exists(cache_file_path):
		print("Warning: Riddle cache file not found at ", cache_file_path)
		return
	
	var file = FileAccess.open(cache_file_path, FileAccess.READ)
	if file == null:
		print("Warning: Could not open riddle cache file.")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_error = json.parse(json_string)
	
	if parse_error != OK:
		print("Warning: Could not parse riddle cache JSON.")
		return
	
	var data = json.data
	#if data.has("riddles") and data["riddles"] is Array:
		#riddle_cache = data["riddles"]
		#print("Loaded ", riddle_cache.size(), " riddles into cache.")
	#else:
		#print("Warning: Riddle cache JSON has invalid format.")

func _get_cached_riddle() -> String:
	"""
	Get a random riddle from cache that hasn't been used recently.
	Returns empty string if cache is empty or all riddles used.
	"""
	if riddle_cache.size() == 0:
		return ""
	
	# If all riddles have been used, reset the used list
	if used_riddles.size() >= riddle_cache.size():
		print("All cached riddles used. Resetting cache usage.")
		used_riddles.clear()
	
	# Get a random index that hasn't been used
	var available_indices: Array[int] = []
	for i in range(riddle_cache.size()):
		if not used_riddles.has(i):
			available_indices.append(i)
	
	if available_indices.size() == 0:
		# All used, reset and try again
		used_riddles.clear()
		available_indices = range(riddle_cache.size())
	
	# Select random unused riddle
	var random_index = available_indices[randi() % available_indices.size()]
	used_riddles.append(random_index)
	
	var cached_riddle = riddle_cache[random_index]
	return cached_riddle.get("riddle", "")

func _add_to_cache(riddle_text: String) -> void:
	"""
	Add a newly generated riddle to the cache (optional feature).
	This allows the cache to grow over time with API-generated riddles.
	"""
	# Extract answer from riddle (basic heuristic - could be improved)
	var answer = _extract_answer_from_riddle(riddle_text)
	
	var new_riddle = {
		"riddle": riddle_text,
		"answer": answer
	}
	
	riddle_cache.append(new_riddle)
	
	# Save updated cache to file (optional - can be disabled to keep cache static)
	# _save_riddle_cache()

func _extract_answer_from_riddle(riddle_text: String) -> String:
	"""
	Basic heuristic to extract answer from riddle.
	In a real implementation, you might want to ask the API for the answer too.
	"""
	# Default to common answers
	var lower_text = riddle_text.to_lower()
	if "forest" in lower_text or "forests" in lower_text:
		return "forest"
	return "tree"  # Default answer

func _save_riddle_cache() -> void:
	"""Save the current riddle cache to JSON file."""
	var data = {
		"riddles": riddle_cache
	}
	
	var json_string = JSON.stringify(data, "\t")
	
	# Note: In Godot, we can't write to res:// at runtime
	# This would need to be saved to user:// directory instead
	# For development, use the pre-generation script instead
	print("Note: Cache saving disabled. Use pre-generation script to update cache.")

func _use_fallback_riddle() -> void:
	"""Use a random fallback riddle when API fails."""
	if fallback_riddles.size() == 0:
		_create_default_fallback_riddles()
	
	var random_index = randi() % fallback_riddles.size()
	var fallback = fallback_riddles[random_index]
	
	print("Using fallback riddle: ", fallback["riddle"])
	riddle_generated.emit(fallback["riddle"])

func _basic_validation(riddle_text: String, player_answer: String) -> void:
	"""Basic validation when API is unavailable (simple keyword matching)."""
	# Try to find the answer in fallback riddles
	for riddle_data in fallback_riddles:
		if riddle_data["riddle"] == riddle_text:
			var correct_answer = riddle_data["answer"].to_lower()
			var player_lower = player_answer.to_lower().strip_edges()
			
			if player_lower == correct_answer:
				answer_validated.emit("CORRECT")
			else:
				answer_validated.emit("INCORRECT: Think about what helps the environment breathe.")
			return
	
	# If riddle not found in fallback, assume incorrect
	answer_validated.emit("INCORRECT: Try thinking about nature and the environment.")
