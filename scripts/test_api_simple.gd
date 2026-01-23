extends Node

## Simple API Test Script
## Attach this to a Node in a scene and run the scene (F6)
## Or call from the main menu script

const GEMINI_API_URL: String = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key="
const API_KEY: String = "AIzaSyCwsby7zG31YB_LKjFxHdxcxAeDrpcvrSs"

var http_request: HTTPRequest

func _ready() -> void:
	print("==================================================")
	print("SIMPLE API TEST")
	print("==================================================")
	
	# Create HTTPRequest
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	http_request.timeout = 10.0
	
	# Test API key
	print("[TEST] API Key: ", API_KEY.substr(0, 10), "...")
	print("[TEST] Making API call...")
	
	# Make test request
	var url = GEMINI_API_URL + API_KEY
	var prompt = "Generate a single riddle in the voice of the lorax about why forests and trees are important for the environment. The answer should be 1-2 words. Only return the riddle text, no extra commentary."
	
	var request_body = {
		"contents": [{
			"parts": [{ 
				"text": prompt
			}]
		}]
	}
	
	var json_body = JSON.stringify(request_body)
	var headers = ["Content-Type: application/json"]
	
	print("[TEST] URL: ", url.substr(0, 80), "...")
	print("[TEST] Request body: ", json_body)
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	
	if error != OK:
		print("[TEST] ERROR: Failed to start request. Error code: ", error)
	else:
		print("[TEST] Request sent. Waiting for response...")

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("==================================================")
	print("[RESPONSE] Result code: ", result)
	print("[RESPONSE] HTTP Response code: ", response_code)
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[RESPONSE] ERROR: Request failed")
		print("[RESPONSE] Error message: ", _get_error_message(result))
		return
	
	if response_code != 200:
		print("[RESPONSE] ERROR: HTTP Error ", response_code)
		print("[RESPONSE] Response body: ", body.get_string_from_utf8())
		return
	
	# Parse JSON
	var body_string = body.get_string_from_utf8()
	print("[RESPONSE] Response body length: ", body_string.length())
	
	var json = JSON.new()
	var parse_error = json.parse(body_string)
	
	if parse_error != OK:
		print("[RESPONSE] ERROR: Failed to parse JSON")
		return
	
	var response_data = json.data
	
	# Extract riddle text
	var response_text = ""
	if response_data.has("candidates") and response_data["candidates"].size() > 0:
		var candidate = response_data["candidates"][0]
		if candidate.has("content") and candidate["content"].has("parts"):
			var parts = candidate["content"]["parts"]
			if parts.size() > 0 and parts[0].has("text"):
				response_text = parts[0]["text"].strip_edges()
	
	if response_text == "":
		print("[RESPONSE] ERROR: Empty response from API")
		return
	
	print("==================================================")
	print("[RESPONSE] SUCCESS!")
	print("[RESPONSE] Riddle received: ", response_text)
	print("==================================================")

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
		_:
			return "Unknown error: " + str(result)
