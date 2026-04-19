extends Control

@onready var captions: Label = $Captions
@onready var text_to_speech: Node = $TextToSpeech

# fade overlay
@onready var fade_canvas: CanvasLayer
@onready var fade_overlay: ColorRect

var tts_preload_dir = "res://assets/audio/text_to_speech_preloaded/end_scene_success/"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for scene in get_children():
		if scene.name.contains("Scene"):
			scene.hide()
	captions.hide()
	
	# setup fade canvas
	fade_canvas = CanvasLayer.new()
	fade_canvas.layer = 5000
	add_child(fade_canvas)
	
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.color.a = 0.0
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_overlay.z_index = 5000
	fade_canvas.add_child(fade_overlay)
	
	fade_canvas.hide()
	
	# preload correct animations
	$HortonScene/Horton.idle_happy_clover(15)
	$BaronScene/Baron.scale = Vector2(0.75, 0.75)
	$BaronScene/Baron.idle_noclover(15)
	
	# make music quieter
	GameState.toggle_background_volume_dim(true)
	
	# play music
	$Music/Default.play()
	
	# Lorax scene
	await _transition(null, $LoraxScene)
	await _lorax_scene()
	
	# Horton scene
	await _transition($LoraxScene, $HortonScene)
	await _horton_scene()
	
	# Baron scene
	await _transition($HortonScene, $BaronScene)
	await _baron_scene()
	
	# make music louder
	GameState.toggle_background_volume_dim(false)


func _transition(prev_scene: Control, next_scene: Control) -> void:
	fade_canvas.show()
	
	# if there was a previous scene, fade it out
	if prev_scene:
		# Fade out
		var fade_tween = create_tween()
		fade_tween.tween_property(fade_overlay, "color:a", 1.0, 1.0)
		await fade_tween.finished
		prev_scene.hide()
	
	# make next scene fade in
	next_scene.show()
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_overlay, "color:a", 0.0, 1.0)
	await fade_tween.finished
	
	fade_canvas.hide()


func _lorax_scene() -> void:
	# let the user acclimate
	await get_tree().create_timer(2).timeout
	captions.show()
	
	text_to_speech.play_voice(tts_preload_dir + "lorax0.mp3")
	captions.text = "Young one, your help, it made things right!"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	text_to_speech.play_voice(tts_preload_dir + "lorax1.mp3")
	captions.text = "The forest now rests, bathed in soft light!"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	text_to_speech.play_voice(tts_preload_dir + "lorax2.mp3")
	captions.text = "Peace has returned, a glorious sight!"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	captions.hide()


func _horton_scene() -> void:	
	# let the user acclimate
	await get_tree().create_timer(2).timeout
	captions.show()
	
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
	
	captions.hide()


func _baron_scene() -> void:
	# let the user acclimate
	await get_tree().create_timer(4).timeout
	captions.show()
	
	text_to_speech.play_voice(tts_preload_dir + "baron0.mp3")
	captions.text = "von Bitey, that menace, with his eye-glass so cold?"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	text_to_speech.play_voice(tts_preload_dir + "baron1.mp3")
	captions.text = "Is now in a cage, his stories untold!"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	text_to_speech.play_voice(tts_preload_dir + "baron2.mp3")
	captions.text = "His scheming is done, brave and bold!"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	captions.hide()
