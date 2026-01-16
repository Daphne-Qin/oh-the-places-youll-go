extends Node

## Riddle Manager (Autoload Singleton)
## Handles riddle generation and validation using local fallback riddles

# Fallback riddles loaded from local JSON
var fallback_riddles: Array[Dictionary] = []

# Riddle cache system
var riddle_cache: Array[Dictionary] = []
var used_riddles: Array[int] = []  # Track indices of used riddles
var cache_file_path: String = "res://resources/riddle_cache.json"

# Signals
signal riddle_generated(riddle_text: String)
signal riddle_generation_failed(error_message: String)
signal answer_validated(result: String)  # "CORRECT" or "INCORRECT: [hint]"
signal answer_validation_failed(error_message: String)

func _ready() -> void:
	"""Initialize the riddle manager."""
	# Load fallback riddles from local JSON
	_load_fallback_riddles()
	
	# Load riddle cache from JSON
	_load_riddle_cache()
	
	print("Riddle Manager initialized.")
	print("Riddle cache loaded: ", riddle_cache.size(), " riddles available")
	print("Fallback riddles loaded: ", fallback_riddles.size(), " riddles available")

func generate_riddle(force_new: bool = false) -> void:
	"""
	Generate a riddle using cache first, then fallback riddles.
	
	Args:
		force_new: If true, skip cache and get a new riddle from fallback
	
	Emits: riddle_generated(riddle_text) or riddle_generation_failed(error_message)
	"""
	# If not forcing new, try cache first
	if not force_new:
		var cached_riddle = _get_cached_riddle()
		if cached_riddle != "":
			print("Using cached riddle")
			riddle_generated.emit(cached_riddle)
			return
	
	# Cache is empty or force_new is true - use fallback
	_use_fallback_riddle()

func validate_answer(riddle_text: String, player_answer: String) -> void:
	"""
	Validate a player's answer using basic validation.
	
	Args:
		riddle_text: The riddle that was asked
		player_answer: The player's answer
	
	Emits: answer_validated(result) or answer_validation_failed(error_message)
	"""
	_basic_validation(riddle_text, player_answer)


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
		fallback_riddles = data["riddles"]
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
		riddle_cache = data["riddles"]
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
	"""Use a random fallback riddle."""
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
