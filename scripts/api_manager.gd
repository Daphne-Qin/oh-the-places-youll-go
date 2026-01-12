extends Node

signal api_request_complete(result: Dictionary)
signal api_request_failed(error: String)

const API_BASE_URL: String = "https://api.example.com"  # Replace with actual API URL
var cache_enabled: bool = true

func _ready() -> void:
	# Initialize API manager
	pass

func request_riddle(topic: String) -> void:
	"""Request a riddle from the API for the given topic."""
	var url: String = API_BASE_URL + "/riddle?topic=" + topic
	
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_riddle_request_complete.bind(request, topic))
	
	var error := request.request(url)
	if error != OK:
		api_request_failed.emit("Failed to start request: " + str(error))

func _on_riddle_request_complete(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest, topic: String) -> void:
	request.queue_free()
	
	if response_code != 200:
		api_request_failed.emit("HTTP Error: " + str(response_code))
		return
	
	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		api_request_failed.emit("JSON Parse Error")
		return
	
	var response_data: Dictionary = json.data
	api_request_complete.emit(response_data)
	
	# Cache the riddle if caching is enabled
	if cache_enabled:
		cache_riddle(topic, response_data)

func cache_riddle(topic: String, riddle_data: Dictionary) -> void:
	"""Cache a riddle to riddle_cache.json."""
	var cache_file := FileAccess.open("res://resources/riddle_cache.json", FileAccess.READ_WRITE)
	if cache_file == null:
		# Create file if it doesn't exist
		cache_file = FileAccess.open("res://resources/riddle_cache.json", FileAccess.WRITE)
	
	if cache_file:
		var cache_data: Dictionary = {}
		var json_string := cache_file.get_as_text()
		if json_string.length() > 0:
			var json := JSON.new()
			json.parse(json_string)
			cache_data = json.data
		
		cache_data[topic] = riddle_data
		
		cache_file.seek(0)
		cache_file.store_string(JSON.stringify(cache_data))
		cache_file.close()
