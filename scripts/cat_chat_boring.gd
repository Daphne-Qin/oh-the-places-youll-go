extends "res://scripts/cat_chat.gd"

## Cat Chat — Boring Path
## Inherits all of cat_chat.gd.
## GameState.baron_has_clover is true when this scene loads, so open_chat()
## will automatically set is_baron_path = true → Path B mechanics activate.

func _on_text_to_speech_voice_loaded() -> void:
	# TTS voice loaded — play it
	if text_to_speech and text_to_speech.has_method("play_voice"):
		text_to_speech.play_voice()
