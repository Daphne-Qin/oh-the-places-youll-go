extends Node

## API Manager - Handles all Gemini API communication
## This is an autoload singleton accessible as APIManager

signal lorax_message_received(message: String)
signal lorax_message_failed(error_message: String)

const GEMINI_API_URL: String = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key="
var api_key: String = ""

func _load_api_key() -> void:
	# Try to load from .env file (gitignored)
	var file = FileAccess.open("res://.env", FileAccess.READ)
	if file:
		while not file.eof_reached():
			var line = file.get_line().strip_edges()
			if line.begins_with("GEMINI_API_KEY="):
				api_key = line.substr(15)
				print("[APIManager] API key loaded from .env")
				return
		file.close()

	print("[APIManager] ERROR: No API key found! Create a .env file with GEMINI_API_KEY=your_key")

const LORAX_SYSTEM_PROMPT: String = """You are the Lorax from Dr. Seuss. You speak for the trees and care deeply about the environment.
Keep your responses short (1-3 sentences), whimsical, and in character.
Use playful, rhyming language when appropriate. Be friendly but passionate about environmental protection."""

var http_request: HTTPRequest

func _ready() -> void:
	print("[APIManager] Initializing...")
	_load_api_key()
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	http_request.timeout = 30.0
	print("[APIManager] Ready")

func send_message_to_lorax(user_message: String) -> void:
	"""Send a message to the Lorax (via Gemini API)."""
	print("[APIManager] Sending message: ", user_message)

	if api_key == "":
		lorax_message_failed.emit("No API key configured. Add GEMINI_API_KEY to .env file.")
		return

	var url = GEMINI_API_URL + api_key

	var request_body = {
		"contents": [{
			"parts": [{
				"text": LORAX_SYSTEM_PROMPT + "\n\nUser: " + user_message + "\n\nLorax:"
			}]
		}],
		"generationConfig": {
			"maxOutputTokens": 150,
			"temperature": 0.8
		}
	}

	var json_body = JSON.stringify(request_body)
	var headers = ["Content-Type: application/json"]

	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

	if error != OK:
		print("[APIManager] ERROR: Failed to start request. Error code: ", error)
		lorax_message_failed.emit("Failed to connect to the API.")

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("[APIManager] Response received. Code: ", response_code)

	if result != HTTPRequest.RESULT_SUCCESS:
		print("[APIManager] Request failed with result: ", result)
		lorax_message_failed.emit(_get_error_message(result))
		return

	if response_code != 200:
		var error_body = body.get_string_from_utf8()
		print("[APIManager] HTTP Error ", response_code, ": ", error_body)
		lorax_message_failed.emit("API returned error " + str(response_code))
		return

	# Parse JSON response
	var body_string = body.get_string_from_utf8()
	var json = JSON.new()
	var parse_error = json.parse(body_string)

	if parse_error != OK:
		print("[APIManager] Failed to parse JSON response")
		lorax_message_failed.emit("Failed to parse API response.")
		return

	var response_data = json.data

	# Extract response text
	var response_text = ""
	if response_data.has("candidates") and response_data["candidates"].size() > 0:
		var candidate = response_data["candidates"][0]
		if candidate.has("content") and candidate["content"].has("parts"):
			var parts = candidate["content"]["parts"]
			if parts.size() > 0 and parts[0].has("text"):
				response_text = parts[0]["text"].strip_edges()

	if response_text == "":
		print("[APIManager] Empty response from API")
		lorax_message_failed.emit("Received empty response from API.")
		return

	print("[APIManager] Success! Response: ", response_text)
	lorax_message_received.emit(response_text)

func _get_error_message(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Cannot connect to server"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Cannot resolve server address"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Connection error"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "No response from server"
		HTTPRequest.RESULT_TIMEOUT:
			return "Request timed out"
		_:
			return "Unknown error: " + str(result)
