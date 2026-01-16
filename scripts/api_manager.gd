extends Node

## Gemini API Manager (Autoload Singleton)
## Handles all API interactions with Google's Gemini API for riddle generation and validation
## Includes comprehensive print tests for debugging

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

# Conversation history for chat dialogue
var conversation_history: Array[Dictionary] = []

# Signals
signal riddle_generated(riddle_text: String)
signal riddle_generation_failed(error_message: String)
signal answer_validated(result: String)  # "CORRECT" or "INCORRECT: [hint]"
signal answer_validation_failed(error_message: String)
signal lorax_message_received(message: String)  # For chat dialogue
signal lorax_message_failed(error_message: String)  # For chat dialogue errors

func _ready() -> void:
	"""Initialize the API manager."""
	print("==================================================")
	print("API MANAGER INITIALIZATION")
	print("==================================================")
	
	# Create HTTPRequest node
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	http_request.timeout = REQUEST_TIMEOUT
	
	# Load fallback riddles from local JSON
	_load_fallback_riddles()
	
	# Load riddle cache from JSON
	_load_riddle_cache()
	
	# Test API key
	var api_key = _get_api_key()
	print("API Key Status: ", "FOUND" if api_key != "" else "NOT FOUND")
	if api_key != "":
		print("API Key (first 10 chars): ", api_key.substr(0, 10), "...")
	else:
		print("WARNING: No API key configured!")
	
	print("API Manager initialized. API Key configured: ", _has_api_key())
	print("Riddle cache loaded: ", riddle_cache.size(), " riddles available")
	print("Fallback riddles loaded: ", fallback_riddles.size(), " riddles available")
	print("==================================================")
	
	# Run test on startup (optional - comment out if causing issues)
	# Uncomment the line below to enable automatic testing on startup
	# call_deferred("_run_startup_test")

func _has_api_key() -> bool:
	"""Check if API key is configured."""
	var api_key = _get_api_key()
	return api_key != "" and api_key != null

func _get_api_key() -> String:
	"""
	Get API key from project settings or environment variable.
	Priority: Project Settings > Environment Variable
	"""
	print("[API KEY CHECK] Checking for API key...")
	
	# Try project settings first
	if ProjectSettings.has_setting("api/gemini_api_key"):
		var key = ProjectSettings.get_setting("api/gemini_api_key")
		if key != null and key != "":
			print("[API KEY CHECK] Found in Project Settings")
			return str(key)
		else:
			print("[API KEY CHECK] Project Settings key is empty")
	
	# Fallback to environment variable
	var env_key = OS.get_environment("GEMINI_API_KEY")
	if env_key != null and env_key != "":
		print("[API KEY CHECK] Found in Environment Variable")
		return env_key
	else:
		print("[API KEY CHECK] Not found in Environment Variable")
	
	# Return empty string if not found
	print("[API KEY CHECK] No API key found!")
	return ""

func _check_rate_limit() -> bool:
	"""Check if enough time has passed since last request (rate limiting)."""
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last = current_time - last_request_time
	
	if time_since_last < RATE_LIMIT_DELAY:
		var wait_time = RATE_LIMIT_DELAY - time_since_last
		print("[RATE LIMIT] Waiting ", wait_time, " seconds before next request")
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
	print("[GENERATE RIDDLE] Called with force_api=", force_api)
	
	# If not forcing API, try cache first
	if not force_api:
		var cached_riddle = _get_cached_riddle()
		if cached_riddle != "":
			print("[GENERATE RIDDLE] Using cached riddle (API call saved!)")
			riddle_generated.emit(cached_riddle)
			return
	
	# Cache is empty or force_api is true - call API
	print("[GENERATE RIDDLE] Cache empty or force_api=true, calling API...")
	_generate_riddle_from_api()

func _generate_riddle_from_api() -> void:
	"""Internal function to generate riddle from API."""
	print("[API CALL] Starting riddle generation from API...")
	
	# Check if already processing a request
	if is_requesting:
		print("[API CALL] ERROR: Another request is already in progress")
		riddle_generation_failed.emit("Another request is already in progress. Please wait.")
		return
	
	# Check rate limiting
	if not _check_rate_limit():
		print("[API CALL] ERROR: Rate limit not met")
		riddle_generation_failed.emit("Please wait a moment before requesting another riddle.")
		return
	
	# Check API key
	if not _has_api_key():
		print("[API CALL] WARNING: No API key found. Using fallback riddle.")
		_use_fallback_riddle()
		return
	
	is_requesting = true
	_update_rate_limit()
	
	# Prepare the API request
	var api_key = _get_api_key()
	var url = GEMINI_API_URL + api_key
	
	print("[API CALL] URL (first 80 chars): ", url.substr(0, 80), "...")
	print("[API CALL] Making HTTP POST request...")
	
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
	
	print("[API CALL] Request body: ", json_body)
	print("[API CALL] Headers: ", headers)
	
	# Make the HTTP request
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	
	if error != OK:
		is_requesting = false
		print("[API CALL] ERROR: Failed to start request. Error code: ", error)
		riddle_generation_failed.emit("Failed to start request: " + str(error))
		_use_fallback_riddle()
	else:
		print("[API CALL] Request sent successfully. Waiting for response...")

func validate_answer(riddle_text: String, player_answer: String) -> void:
	"""
	Validate a player's answer using Gemini API.
	
	Args:
		riddle_text: The riddle that was asked
		player_answer: The player's answer
	
	Emits: answer_validated(result) or answer_validation_failed(error_message)
	"""
	print("[VALIDATE ANSWER] Called")
	print("[VALIDATE ANSWER] Riddle: ", riddle_text)
	print("[VALIDATE ANSWER] Player answer: ", player_answer)
	
	# Check if already processing a request
	if is_requesting:
		print("[VALIDATE ANSWER] ERROR: Another request in progress")
		answer_validation_failed.emit("Another request is already in progress. Please wait.")
		return
	
	# Check rate limiting
	if not _check_rate_limit():
		print("[VALIDATE ANSWER] ERROR: Rate limit not met")
		answer_validation_failed.emit("Please wait a moment before validating again.")
		return
	
	# Check API key
	if not _has_api_key():
		print("[VALIDATE ANSWER] WARNING: No API key found. Using basic validation.")
		_basic_validation(riddle_text, player_answer)
		return
	
	is_requesting = true
	_update_rate_limit()
	
	# Prepare the API request
	var api_key = _get_api_key()
	var url = GEMINI_API_URL + api_key
	
	print("[VALIDATE ANSWER] Making API call...")
	
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
	
	print("[VALIDATE ANSWER] Request body: ", json_body)
	
	# Make the HTTP request
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	
	if error != OK:
		is_requesting = false
		print("[VALIDATE ANSWER] ERROR: Failed to start request. Error code: ", error)
		answer_validation_failed.emit("Failed to start request: " + str(error))
		_basic_validation(riddle_text, player_answer)

func send_message_to_lorax(user_message: String) -> void:
	"""
	Send a message to the Lorax and get a conversational response.
	Maintains conversation history for context.
	
	Args:
		user_message: The player's message to the Lorax
	
	Emits: lorax_message_received(message) or lorax_message_failed(error_message)
	"""
	print("[LORAX CHAT] User message: ", user_message)
	
	# Check if already processing a request
	if is_requesting:
		print("[LORAX CHAT] ERROR: Another request in progress")
		lorax_message_failed.emit("The Lorax is thinking... Please wait.")
		return
	
	# Check rate limiting
	if not _check_rate_limit():
		print("[LORAX CHAT] ERROR: Rate limit not met")
		lorax_message_failed.emit("Please wait a moment before sending another message.")
		return
	
	# Check API key
	if not _has_api_key():
		print("[LORAX CHAT] WARNING: No API key found. Using fallback response.")
		_use_fallback_lorax_response(user_message)
		return
	
	# Add user message to conversation history
	conversation_history.append({
		"role": "user",
		"text": user_message
	})
	
	# Limit conversation history to last 10 messages to avoid token limits
	if conversation_history.size() > 10:
		conversation_history = conversation_history.slice(-10)
	
	is_requesting = true
	_update_rate_limit()
	
	# Build conversation context with Lorax personality
	var system_instruction = "You are the Lorax from Dr. Seuss's 'The Lorax'. You speak for the trees and care deeply about the environment. Keep your responses SHORT (1-2 sentences max). Be wise, caring, and use simple, poetic language. Speak in the voice of the Lorax - protective of nature, but hopeful and encouraging."
	
	# Build conversation messages - include full history
	var messages = []
	
	# Build the conversation prompt with system instruction
	var conversation_text = system_instruction + "\n\n"
	
	# Add conversation history
	for i in range(conversation_history.size()):
		var msg = conversation_history[i]
		if msg["role"] == "user":
			conversation_text += "User: " + msg["text"] + "\n"
		else:
			conversation_text += "Lorax: " + msg["text"] + "\n"
	
	# Add the current user message
	conversation_text += "User: " + user_message + "\n"
	conversation_text += "Lorax:"
	
	# Create single user message with full conversation context
	messages.append({
		"role": "user",
		"parts": [{"text": conversation_text}]
	})
	
	# Prepare the API request
	var api_key = _get_api_key()
	var url = GEMINI_API_URL + api_key
	
	print("[LORAX CHAT] Making API call with ", conversation_history.size(), " messages in history...")
	
	var request_body = {
		"contents": messages
	}
	
	var json_body = JSON.stringify(request_body)
	var headers = ["Content-Type: application/json"]
	
	print("[LORAX CHAT] Request body (first 500 chars): ", json_body.substr(0, 500))
	print("[LORAX CHAT] Total messages in request: ", messages.size())
	
	# Store request type to handle response correctly
	http_request.set_meta("request_type", "lorax_chat")
	
	# Make the HTTP request
	print("[LORAX CHAT] Making HTTP request...")
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	
	if error != OK:
		is_requesting = false
		print("[LORAX CHAT] ERROR: Failed to start request. Error code: ", error)
		lorax_message_failed.emit("Failed to connect to the Lorax. Please try again.")
		conversation_history.pop_back()  # Remove failed message from history
	else:
		print("[LORAX CHAT] HTTP request sent successfully. Waiting for response...")

func _use_fallback_lorax_response(user_message: String) -> void:
	"""Use a fallback response when API is unavailable."""
	print("[LORAX CHAT] Using fallback response (API unavailable or failed)")
	
	# Try to give a contextual response based on user message if possible
	var fallback_responses = [
		"I speak for the trees, for the trees have no tongues.",
		"Unless someone like you cares a whole awful lot, nothing is going to get better.",
		"The trees need your help, young friend.",
		"Plant a seed, watch it grow. That's how we save the forest.",
		"Every tree matters. Every leaf counts.",
		"I care about the forest and all who live there.",
		"Protect the trees, and they will protect you.",
		"Nature needs our help, now more than ever."
	]
	
	var response = fallback_responses[randi() % fallback_responses.size()]
	
	# Only add to history if we're actually in a conversation
	if conversation_history.size() > 0:
		conversation_history.append({
			"role": "model",
			"text": response
		})
	
	print("[LORAX CHAT] Fallback response: ", response)
	lorax_message_received.emit(response)

func clear_conversation() -> void:
	"""Clear the conversation history."""
	conversation_history.clear()
	print("[LORAX CHAT] Conversation history cleared")

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Handle HTTP request completion."""
	print("==================================================")
	print("[API RESPONSE] Request completed")
	print("[API RESPONSE] Result code: ", result)
	print("[API RESPONSE] HTTP Response code: ", response_code)
	print("[API RESPONSE] Headers count: ", headers.size())
	
	is_requesting = false
	
	# Check request type early for proper error handling
	var request_type = http_request.get_meta("request_type", "")
	
	# Check for HTTP errors
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg = _get_error_message(result)
		print("[API RESPONSE] ERROR: ", error_msg)
		
		# Handle based on request type
		if request_type == "lorax_chat":
			lorax_message_failed.emit(error_msg)
			_use_fallback_lorax_response("")
		else:
			riddle_generation_failed.emit(error_msg)
			answer_validation_failed.emit(error_msg)
			_use_fallback_riddle()
		
		print("==================================================")
		return
	
	if response_code != 200:
		var error_msg = "HTTP Error: " + str(response_code)
		print("[API RESPONSE] ERROR: ", error_msg)
		print("[API RESPONSE] Response body: ", body.get_string_from_utf8())
		
		# Handle based on request type
		if request_type == "lorax_chat":
			lorax_message_failed.emit(error_msg)
			_use_fallback_lorax_response("")
		else:
			riddle_generation_failed.emit(error_msg)
			answer_validation_failed.emit(error_msg)
			_use_fallback_riddle()
		
		print("==================================================")
		return
	
	# Parse JSON response
	var body_string = body.get_string_from_utf8()
	print("[API RESPONSE] Response body length: ", body_string.length())
	print("[API RESPONSE] Response body (first 200 chars): ", body_string.substr(0, 200))
	
	var json = JSON.new()
	var parse_error = json.parse(body_string)
	
	if parse_error != OK:
		var error_msg = "Failed to parse API response"
		print("[API RESPONSE] ERROR: ", error_msg)
		print("[API RESPONSE] Parse error: ", parse_error)
		
		# Handle based on request type
		if request_type == "lorax_chat":
			lorax_message_failed.emit(error_msg)
			_use_fallback_lorax_response("")
		else:
			riddle_generation_failed.emit(error_msg)
			answer_validation_failed.emit(error_msg)
			_use_fallback_riddle()
		
		print("==================================================")
		return
	
	var response_data = json.data
	print("[API RESPONSE] Parsed JSON successfully")
	print("[API RESPONSE] Response data keys: ", response_data.keys())
	
	# Extract text from Gemini API response
	var response_text = ""
	if response_data.has("candidates") and response_data["candidates"].size() > 0:
		var candidate = response_data["candidates"][0]
		print("[API RESPONSE] Candidate found")
		if candidate.has("content") and candidate["content"].has("parts"):
			var parts = candidate["content"]["parts"]
			print("[API RESPONSE] Parts count: ", parts.size())
			if parts.size() > 0 and parts[0].has("text"):
				response_text = parts[0]["text"].strip_edges()
				print("[API RESPONSE] Extracted text: ", response_text)
	
	if response_text == "":
		var error_msg = "Empty response from API"
		print("[API RESPONSE] ERROR: ", error_msg)
		print("[API RESPONSE] Full response data: ", response_data)
		
		# Handle based on request type
		if request_type == "lorax_chat":
			print("[API RESPONSE] Empty response - using fallback for Lorax chat")
			print("[API RESPONSE] This might mean API key is invalid or request format is wrong")
			# Use fallback but don't emit failed signal (fallback will emit received)
			_use_fallback_lorax_response("")
		else:
			riddle_generation_failed.emit(error_msg)
			answer_validation_failed.emit(error_msg)
			_use_fallback_riddle()
		
		print("==================================================")
		return
	
	if request_type == "lorax_chat":
		# This is a Lorax chat response
		print("[API RESPONSE] Detected as Lorax chat response")
		
		# Add Lorax response to conversation history
		conversation_history.append({
			"role": "model",
			"text": response_text
		})
		
		# Limit history size
		if conversation_history.size() > 10:
			conversation_history = conversation_history.slice(-10)
		
		lorax_message_received.emit(response_text)
		http_request.remove_meta("request_type")
	
	elif response_text.to_upper().begins_with("CORRECT") or response_text.to_upper().begins_with("INCORRECT"):
		# This is a validation response
		print("[API RESPONSE] Detected as validation response")
		answer_validated.emit(response_text)
	else:
		# This is a riddle generation response
		print("[API RESPONSE] Detected as riddle generation response")
		riddle_generated.emit(response_text)
	
	print("==================================================")

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
		var riddles_array = data["riddles"] as Array
		fallback_riddles.clear()
		for riddle in riddles_array:
			if riddle is Dictionary:
				fallback_riddles.append(riddle)
		print("Loaded ", fallback_riddles.size(), " fallback riddles from JSON.")
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
	if data.has("riddles") and data["riddles"] is Array:
		var riddles_array = data["riddles"] as Array
		riddle_cache.clear()
		for riddle in riddles_array:
			if riddle is Dictionary:
				riddle_cache.append(riddle)
		print("Loaded ", riddle_cache.size(), " riddles into cache.")
	else:
		print("Warning: Riddle cache JSON has invalid format.")

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

func _run_startup_test() -> void:
	"""Run a test API call on startup to verify everything works."""
	print("==================================================")
	print("RUNNING STARTUP API TEST")
	print("==================================================")
	
	# Wait a moment for everything to initialize
	await get_tree().create_timer(1.0).timeout
	
	if not _has_api_key():
		print("[TEST] Skipping API test - no API key found")
		return
	
	print("[TEST] Testing riddle generation...")
	riddle_generated.connect(_on_test_riddle_received)
	riddle_generation_failed.connect(_on_test_riddle_failed)
	generate_riddle(true)  # Force API call

func _on_test_riddle_received(riddle_text: String) -> void:
	"""Handle test riddle generation success."""
	print("[TEST] SUCCESS! Riddle received: ", riddle_text)
	print("==================================================")
	riddle_generated.disconnect(_on_test_riddle_received)
	riddle_generation_failed.disconnect(_on_test_riddle_failed)

func _on_test_riddle_failed(error_message: String) -> void:
	"""Handle test riddle generation failure."""
	print("[TEST] FAILED! Error: ", error_message)
	print("==================================================")
	riddle_generated.disconnect(_on_test_riddle_received)
	riddle_generation_failed.disconnect(_on_test_riddle_failed)
