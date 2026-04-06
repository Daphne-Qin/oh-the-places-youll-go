extends Node

var effect
var recording
var attempts = 0
var MAX_ATTEMPTS = 3
const save_path = "user://temp_wav_stt.wav"
var is_recording = false

var _pending_data = null

var api_key = ""

signal loading(time)
signal received(text)

func _ready():
	var idx = AudioServer.get_bus_index("Record")
	effect = AudioServer.get_bus_effect(idx, 0)
	_load_api_key()

func _load_api_key() -> void:
	var file = FileAccess.open("res://.env", FileAccess.READ)
	if file:
		while not file.eof_reached():
			var line = file.get_line().strip_edges()
			if line.begins_with("HUGGINGFACE_API_KEY="):
				api_key = line.split("=")[1]
				print("[STT] API key loaded from .env")
				return
		file.close()
	print("[STT] ERROR: No API key found! Create a .env file with HUGGINGFACE_API_KEY=your_key")

func _process_request(data):
	# send to Whisper
	print("Sending %d bytes to HuggingFace..." % data.size())
	$HTTPRequest.request_raw(
		"https://router.huggingface.co/hf-inference/models/openai/whisper-large-v3-turbo",
		["Authorization: Bearer %s" % api_key, "Content-Type: audio/wav"],
		HTTPClient.METHOD_POST,
		data
	)

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var response = json.get_data()
	print("[STT] full response:", response)
	
	# server unavailable, try up to MAX_ATTEMPTS times
	if response_code == 503 and attempts < MAX_ATTEMPTS:
		emit_signal("Response code 503", response["estimated_time"])
		attempts += 1
		$Timer.start() # reload
	else:
		if attempts >= MAX_ATTEMPTS or response == null:
			printerr("[STT]: There was an error with processing the request.")
		else:
			emit_signal("received", response["text"].strip_edges())

func start_recording():
	print("[STT]: Started recording")
	is_recording = true
	effect.set_recording_active(true)

func stop_recording():
	# wait 0.5 secs as buffer
	await get_tree().create_timer(0.5).timeout
	print("[STT]: Stopped recording")
	effect.set_recording_active(false)
	is_recording = false
	recording = effect.get_recording()
	
	var err = await recording.save_to_wav(save_path)
	if err != OK:
		printerr("[STT]: Failed to save WAV, error: ", err)
		return
	
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		printerr("[STT]: Failed to open saved WAV at: ", save_path)
		printerr("FileAccess error: ", FileAccess.get_open_error())
		return
	
	_pending_data = file.get_buffer(file.get_length())
	file.close()
	attempts = 0
	_process_request(_pending_data)

func _on_timer_timeout() -> void:
	_process_request(_pending_data)
