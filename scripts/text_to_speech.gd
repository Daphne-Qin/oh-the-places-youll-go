extends Node

var effect
var recording
var attempts = 0
var MAX_ATTEMPTS = 3
const save_path = "user://temp_wav_tts.wav"
var is_recording = false
@onready var audio_player = $AudioStreamPlayer

var _pending_character := ""
var _pending_text := ""

var audio_length = 0

signal voice_loaded

var api_key = ""

var voice_models = {
	'lorax': 'b2790e333a6e40f69a8b9bc8865b530b',
	'cat': 'e96f323d076249adb2ff0f97ebb23bbe',
	'horton': 'f3f61e8ceb924f3482afb76ab0f86829',
	'bitey': '75c860b53da84405aa49718cdda8c83e',
	'baron': '75c860b53da84405aa49718cdda8c83e' # bitey/baron used interchangably so are the same
}

func _ready():
	_load_api_key()

func _load_api_key() -> void:
	var file = FileAccess.open("res://.env", FileAccess.READ)
	if file:
		while not file.eof_reached():
			var line = file.get_line().strip_edges()
			if line.begins_with("FISHAUDIO_API_KEY="):
				api_key = line.split("=")[1]
				print("[TTS] API key loaded from .env")
				return
		file.close()
	print("[TTS] ERROR: No API key found! Create a .env file with FISHAUDIO_API_KEY=your_key")

func _process_request(character: String, text: String):
	var reference_id = voice_models[character]
	var body = JSON.stringify({
		'text': text,
		'reference_id': reference_id,
		'format': 'mp3',
		'latency': 'normal'
	})
	
	# send to Fish Audio
	print("[TTS] Sending %d characters to Fish Audio model %s..." % [text.length(), character])
	var err = $HTTPRequest.request(
		"https://api.fish.audio/v1/tts",
		[
			"Authorization: Bearer %s" % api_key,
			"Content-Type: application/json"
		],
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		printerr("[TTS] HTTPRequest error: ", err)
		audio_length = 0
		

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 503:
		if attempts < MAX_ATTEMPTS:
			var json = JSON.new()
			json.parse(body.get_string_from_utf8())
			var response = json.get_data()
			emit_signal("Response code 503", response["estimated_time"])
			attempts += 1
			$Timer.start()
		else:
			printerr("[TTS]: Max attempts reached.")
			audio_length = 0
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		printerr("[TTS]: Request failed with result: ", result)
		audio_length = 0
		return

	if body.size() == 0:
		printerr("[TTS] Empty body received.")
		audio_length = 0
		emit_signal("tts_failed", "empty body")
		return

	print("[TTS] Processing audio...")
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		printerr("[TTS] Could not open save path: ", save_path)
		return
	file.store_buffer(body)
	file.close()

	emit_signal("voice_loaded")
	print("[TTS] Audio saved (%d bytes), length: %.2fs" % [body.size(), audio_length])

func play_voice(filepath: String = "") -> void:
	var stream = AudioStreamMP3.new()
	var file = null
	if filepath == "":
		file = FileAccess.open(save_path, FileAccess.READ)
	else:
		file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		printerr("[TTS] Could not read saved audio.")
		return
	stream.data = file.get_buffer(file.get_length())
	file.close()
	audio_player.stream = stream
	audio_length = stream.get_length()
	print("[TTS] Playing audio!")
	audio_player.play()

func load_voice(character: String, text: String):
	if not GameState.tts_on:
		return

	if not voice_models.has(character):
		printerr("[TTS] Unknown character:", character)
		return
	
	_pending_character = character
	var regex = RegEx.new()
	regex.compile("\\*[^*]*\\s[^*]*\\*")
	_pending_text = regex.sub(text, "", true)
	attempts = 0
	_process_request(_pending_character, _pending_text)

func stop_voice():
	audio_player.stop()

func _on_timer_timeout() -> void:
	_process_request(_pending_character, _pending_text)
