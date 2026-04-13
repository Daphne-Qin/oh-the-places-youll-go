extends Control

@onready var captions: Label = $Captions
@onready var text_to_speech: Node = $TextToSpeech

var tts_preload_dir = "res://assets/audio/text_to_speech_preloaded/end_scene_failure/"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for scene in get_children():
		if scene.name.contains("Scene"):
			scene.hide()
	captions.hide()
	
	# make music quieter
	GameState.toggle_background_volume_dim(true)
	
	# play music
	$Music/Default.play()
	
	# Lorax scene
	_transition(null, $GrandMonotonyScene, _grand_monotony_scene)
	await get_tree().create_timer(35).timeout
	
	# Horton scene
	_transition($GrandMonotonyScene, $MudScene, _mud_scene)
	await get_tree().create_timer(35).timeout
	
	# Baron scene
	_transition($MudScene, $ShootingStarsScene, _shooting_stars_scene)
	await get_tree().create_timer(35).timeout	
	
	# make music louder
	GameState.toggle_background_volume_dim(false)


func _transition(prev_scene: Control, next_scene: Control, next_function: Callable) -> void:
	# if there was a previous scene, fade it out
	if prev_scene:
		# Fade out
		var tween = create_tween()
		tween.tween_property(prev_scene, "modulate:a", 0.0, 2.0)
		await tween.finished
		prev_scene.hide()

	# Prepare next scene invisible, then fade in
	next_scene.modulate.a = 0.0
	next_scene.show()
	next_function.call()

	var tween2 = create_tween()
	tween2.tween_property(next_scene, "modulate:a", 1.0, 2.0)
	await tween2.finished

func _grand_monotony_scene() -> void:
	# let the user acclimate
	await get_tree().create_timer(4).timeout
	captions.show()
	
	text_to_speech.play_voice(tts_preload_dir + "monotony0.mp3")
	captions.text = "… The trees… they’re gone… all of them… replaced by… his hat… just his hat, over and over…"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	text_to_speech.play_voice(tts_preload_dir + "monotony1.mp3")
	captions.text = "This is what they meant… everything the same… no voices, no differences… no Whoville…"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	text_to_speech.play_voice(tts_preload_dir + "monotony2.mp3")
	captions.text = "And even the Whos are gone… that Baron made the Cat eat them…"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	captions.hide()


func _mud_scene() -> void:
	# let the user acclimate
	await get_tree().create_timer(4).timeout
	captions.show()
	
	text_to_speech.play_voice(tts_preload_dir + "mud0.mp3")
	captions.text = "Oh… it’s so quiet here… even the ground feels… sad…"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	text_to_speech.play_voice(tts_preload_dir + "mud1.mp3")
	captions.text = "Without the trees… without their colors… it’s like the whole world forgot how to speak…"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	text_to_speech.play_voice(tts_preload_dir + "mud2.mp3")
	captions.text = "…the Lorax would be so… so heartbroken to see this…"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	captions.hide()


func _shooting_stars_scene() -> void:
	# let the user acclimate
	await get_tree().create_timer(4).timeout
	captions.show()
	
	text_to_speech.play_voice(tts_preload_dir + "stars0.mp3")
	captions.text = "…stars… even now, they’re still moving… still hoping…"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	text_to_speech.play_voice(tts_preload_dir + "stars1.mp3")
	captions.text = "Maybe… someday… someone else will hear what others cannot… someone who won’t doubt…"
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	text_to_speech.play_voice(tts_preload_dir + "stars2.mp3")
	captions.text = "Someone who not only hears… but knows they must act… and means what they say… one hundred percent."
	await get_tree().create_timer(text_to_speech.audio_length + 1).timeout
	
	captions.hide()
