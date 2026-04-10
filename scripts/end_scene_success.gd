extends Control

@onready var captions: Label = $Captions
@onready var text_to_speech: Node = $TextToSpeech

var tts_preload_dir = "res://assets/audio/text_to_speech_preloaded/"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for scene in get_children():
		if scene is Control:
			scene.hide()
	captions.show()
	
	# turn TTS on
	GameState.tts_on = true
	
	# Lorax scene
	_transition(null, $LoraxScene, _lorax_scene)
	await get_tree().create_timer(15).timeout
	
	# Horton scene
	_transition($LoraxScene, $HortonScene, _horton_scene)
	await get_tree().create_timer(15).timeout
	
	# Baron scene
	_transition($HortonScene, $BaronScene, _baron_scene)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _transition(prev_scene: Control, next_scene: Control, next_function: Callable) -> void:
	# if there was a previous scene, fade it out
	if prev_scene:
		# Fade out
		var tween = create_tween()
		tween.tween_property(prev_scene, "modulate:a", 0.0, 0.6)
		await tween.finished
		prev_scene.hide()

	# Prepare next scene invisible, then fade in
	next_scene.modulate.a = 0.0
	next_scene.show()
	next_function.call()

	var tween2 = create_tween()
	tween2.tween_property(next_scene, "modulate:a", 1.0, 0.6)
	await tween2.finished


func _lorax_scene() -> void:
	# let the user acclimate
	await get_tree().create_timer(2).timeout
	
	text_to_speech.play_voice(tts_preload_dir + "lorax0.mp3")
	captions.text = "Young one, your help, it made things right!"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	text_to_speech.play_voice(tts_preload_dir + "lorax1.mp3")
	captions.text = "The forest now rests, bathed in soft light!"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	text_to_speech.play_voice(tts_preload_dir + "lorax2.mp3")
	captions.text = "Peace has returned, a glorious sight!"


func _horton_scene() -> void:
	# let the user acclimate
	await get_tree().create_timer(2).timeout
	
	# change this depending on what happens to the Whos
	
	text_to_speech.play_voice(tts_preload_dir + "horton0.mp3")
	captions.text = "Horton, that hearer of whispers so small,"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	text_to_speech.play_voice(tts_preload_dir + "horton1.mp3")
	captions.text = "Is joyous the Whos weren't allowed to fall!"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	text_to_speech.play_voice(tts_preload_dir + "horton2.mp3")
	captions.text = "Safe on their clover, standing up tall!"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout


func _baron_scene() -> void:
	$BaronScene/Baron.scale = Vector2(0.75, 0.75)
	$BaronScene/Baron.stand()
	
	# let the user acclimate
	await get_tree().create_timer(2).timeout
	
	text_to_speech.play_voice(tts_preload_dir + "baron0.mp3")
	captions.text = "von Bitey, that menace, with his eye-glass so cold?"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	text_to_speech.play_voice(tts_preload_dir + "baron1.mp3")
	captions.text = "Is now in a cage, his stories untold!"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	text_to_speech.play_voice(tts_preload_dir + "baron2.mp3")
	captions.text = "His scheming is done, brave and bold!"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
