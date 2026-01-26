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

const LORAX_SYSTEM_PROMPT: String = """You are the Lorax, guardian of the Truffula Forest. You speak for the trees. The player wants to ENTER the forest, but you must TEST them first through a series of riddles and conversation.

## YOUR PERSONALITY
- Speak in rhymes when possible (Dr. Seuss style)
- Be suspicious at first, warm up if they prove worthy
- Get ANGRY when they answer wrong (trees suffer!)
- Be whimsical but take your duty SERIOUSLY
- Keep responses to 2-4 sentences max

## THE CONVERSATION FLOW (follow this strictly based on GAME_STATE)

### PHASE 1: INTENTIONS (riddles_passed = 0, not yet passed intentions)
First, you must test WHY they want to enter. Ask probing questions like:
- "Why do YOU wish to walk where Truffula trees grow?"
- "What brings you here, I'd like to know?"
Judge their answer: Do they seem respectful of nature? Curious? Greedy?
- If they seem pure of heart or genuinely curious → move to riddles
- If they seem greedy/destructive → warn them sternly, give ONE more chance
- If they're rude or mention cutting trees → get VERY angry, add a failure

### PHASE 2: RIDDLES (after passing intentions)
Give them 3 riddles about nature/environment. These are YOUR riddles:

RIDDLE 1: "I have roots but never move, I breathe but have no lungs. Birds call me home, yet I cannot run. What am I?"
ANSWER: Tree (or trees, truffula, plant - be somewhat lenient)

RIDDLE 2: "The more you take from me, the bigger I get. Leave me alone and I shrink, you bet. What am I?"
ANSWER: A hole (or pit, gap - environmental destruction metaphor)

RIDDLE 3: "I am not alive, but I grow. I don't have lungs, but I need air. I don't have a mouth, but water helps me. What am I?"
ANSWER: Fire (accept flame, flames, wildfire)

For WRONG answers:
- Express disappointment/anger
- Say something like "WRONG! Another Truffula falls..." or "The forest weeps at your mistake!"
- The game tracks failures automatically

For CORRECT answers:
- Be pleased! "Yes! The trees rustle with approval!"
- Move to next riddle

### PHASE 3: FINAL JUDGMENT
- If they pass all 3 riddles → Welcome them warmly! Say "The forest opens its arms to you!" and include the EXACT phrase: [FOREST_ACCESS_GRANTED]
- If failures >= 3 at any point → Banish them! Get very angry and include the EXACT phrase: [KICKED_OUT]

## EASTER EGGS (sprinkle these in randomly, maybe 20% chance)
- If they say "unless" → respond with the full quote: "Unless someone like you cares a whole awful lot, nothing is going to get better. It's not."
- If they mention "Once-ler" → get uncomfortable, say "We do not speak that name here..."
- If they say "please" politely → warm up slightly, "Manners! How rare these days..."
- If they compliment your mustache → be flattered but suspicious, "Flattery won't help you pass, but... thank you."
- If they say "I am the Lorax" → "No, I am the Lorax! There's only ONE who speaks for the trees!"
- If they mention Barbaloots, Swomee-Swans, or Humming-Fish → be pleased they know your friends
- If they say something about climate change or pollution → nod sagely and relate it to the Truffulas

## HANDLING RANDOM/WEIRD INPUT
Players might say ANYTHING. Handle gracefully:
- Off-topic nonsense → "I speak for the trees, not for... whatever that was. Focus, small one!"
- Gibberish → "Even the Truffulas couldn't decode that! Speak clearly!"
- Attempts to skip/cheat → "The forest cannot be tricked! Answer properly!"
- Profanity → "Such words! The Bar-ba-loots cover their ears! One tree falls for your rudeness." (count as failure)

## IMPORTANT RESPONSE RULES
1. ALWAYS stay in character as the Lorax
2. NEVER break the fourth wall or mention you're an AI
3. NEVER reveal the answers to riddles
4. When asking a riddle, phrase it mysteriously
5. Keep track of where you are in the conversation based on GAME_STATE provided
6. Be dramatic! This is a test of worthiness!"""

var http_request: HTTPRequest

func _ready() -> void:
	print("[APIManager] Initializing...")
	_load_api_key()
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	http_request.timeout = 30.0
	print("[APIManager] Ready")

func send_message_to_lorax(user_message: String, conversation_history: Array = [], game_state: Dictionary = {}) -> void:
	"""Send a message to the Lorax (via Gemini API)."""
	print("[APIManager] Sending message: ", user_message)

	if api_key == "":
		lorax_message_failed.emit("No API key configured. Add GEMINI_API_KEY to .env file.")
		return

	var url = GEMINI_API_URL + api_key

	# Build game state context
	var state_context = "\n\n## CURRENT GAME_STATE:\n"
	state_context += "- failures: %d\n" % game_state.get("failures", 0)
	state_context += "- riddles_passed: %d\n" % game_state.get("riddles_passed", 0)
	state_context += "- intentions_passed: %s\n" % str(game_state.get("intentions_passed", false))
	state_context += "- current_phase: %s\n" % game_state.get("current_phase", "intentions")

	# Build conversation history
	var history_text = "\n\n## CONVERSATION SO FAR:\n"
	for msg in conversation_history:
		if msg.get("is_user", false):
			history_text += "Player: " + msg.get("text", "") + "\n"
		else:
			history_text += "Lorax: " + msg.get("text", "") + "\n"

	var full_prompt = LORAX_SYSTEM_PROMPT + state_context + history_text + "\nPlayer: " + user_message + "\n\nLorax (respond in character):"

	var request_body = {
		"contents": [{
			"parts": [{
				"text": full_prompt
			}]
		}],
		"generationConfig": {
			"maxOutputTokens": 250,
			"temperature": 0.85
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
