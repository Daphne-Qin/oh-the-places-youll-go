extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$TextToSpeech.load_voice('lorax', "My name is the Lorax and I speak for the trees!")


func _on_text_to_speech_voice_loaded() -> void:
	$TextToSpeech.play_voice()
