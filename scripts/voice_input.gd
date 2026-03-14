extends Node

## VoiceInput — Web Speech API bridge (web export only)
## Autoload singleton. Usage:
##   VoiceInput.start_listening()
##   VoiceInput.voice_result  → emits(transcript: String)
##   VoiceInput.voice_error   → emits(reason: String)
##   VoiceInput.is_available() → bool

signal voice_result(transcript: String)
signal voice_error(reason: String)

var is_listening: bool = false

var _poll_timer: Timer

func _ready() -> void:
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.15
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(_poll_for_result)
	add_child(_poll_timer)

func is_available() -> bool:
	if not JavaScriptBridge.is_available():
		return false
	var supported = JavaScriptBridge.eval(
		"(typeof window.SpeechRecognition !== 'undefined' || typeof window.webkitSpeechRecognition !== 'undefined')"
	)
	return supported == true

func start_listening() -> void:
	if is_listening:
		return
	if not is_available():
		voice_error.emit("not_supported")
		return

	is_listening = true
	JavaScriptBridge.eval("""
		window._godot_voice_result = null;
		var SR = window.SpeechRecognition || window.webkitSpeechRecognition;
		window._godot_sr = new SR();
		window._godot_sr.lang = 'en-US';
		window._godot_sr.interimResults = false;
		window._godot_sr.maxAlternatives = 1;
		window._godot_sr.onresult = function(e) {
			window._godot_voice_result = {ok: true, text: e.results[0][0].transcript};
		};
		window._godot_sr.onerror = function(e) {
			window._godot_voice_result = {ok: false, text: e.error};
		};
		window._godot_sr.onend = function() {
			if (!window._godot_voice_result)
				window._godot_voice_result = {ok: false, text: 'cancelled'};
		};
		window._godot_sr.start();
	""")
	_poll_timer.start()

func stop_listening() -> void:
	if not is_listening:
		return
	JavaScriptBridge.eval("if(window._godot_sr) { window._godot_sr.stop(); }")

func _poll_for_result() -> void:
	var result = JavaScriptBridge.eval("window._godot_voice_result ? JSON.stringify(window._godot_voice_result) : null")
	if result == null or result == "null":
		return

	_poll_timer.stop()
	is_listening = false

	# Clear the JS-side result
	JavaScriptBridge.eval("window._godot_voice_result = null;")

	var json = JSON.new()
	if json.parse(str(result)) == OK and json.data is Dictionary:
		if json.data.get("ok", false):
			voice_result.emit(json.data.get("text", ""))
		else:
			voice_error.emit(json.data.get("text", "error"))
	else:
		voice_error.emit("parse_error")
