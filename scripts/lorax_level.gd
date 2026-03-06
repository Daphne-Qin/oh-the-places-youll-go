extends Node2D

## Lorax Level Script
## Manages the game level, interactions, and chat interface

@onready var lorax: Area2D = $Interactables/Lorax
@onready var player: CharacterBody2D = $Player

@onready var current_music: AudioStreamPlayer = null

# Interaction prompt UI
var is_near_lorax: bool = false
var chat_instance: Control = null
var level_select: Control = null
var camera: Camera2D = null

func _ready() -> void:
	"""Initialize the level."""
	GameState.enable_movement()
	
	# Connect Lorax area signals
	if lorax:
		lorax.body_entered.connect(_on_lorax_area_entered)
		lorax.body_exited.connect(_on_lorax_area_exited)
	
	# set camera
	camera = $Player/Camera2D
	camera.limit_left = 0
	camera.limit_right = 1280
	camera.limit_top = 0
	camera.limit_bottom = 720

	# level menu
	level_select = GameState.load_top_scene("res://scenes/LevelSelector.tscn")
	level_select.hide()
	
	# start music
	_switch_music($Music/Default)
	

func _switch_music(new_music: AudioStreamPlayer) -> void:
	if new_music == current_music:
		return
		
	var music_fade_time = 1

	var tween = create_tween()

	# Fade out old track
	if current_music and current_music.playing:
		tween.tween_property(current_music, "volume_db", -40.0, music_fade_time)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		await tween.finished

	# Stop old music AFTER fade
	if current_music and current_music != new_music:
		current_music.stop()
	
	# set new music
	current_music = new_music
	current_music.volume_db = 0.0
	current_music.play()

func _load_chat_interface() -> void:
	"""Load and add the chat interface to the scene."""
	chat_instance = GameState.load_top_scene("res://scenes/LoraxChat.tscn")
	chat_instance.hide()
	
	# level completed signal
	if chat_instance.has_signal("player_granted_access"):
		chat_instance.player_granted_access.connect(_on_player_granted_access)
		print("[LEVEL] Connected player_granted_access signal")

func _on_lorax_area_entered(body: Node2D) -> void:
	"""Called when player enters the Lorax interaction area."""
	if body == player:
		is_near_lorax = true
		$InteractionLabel.text = "Press [E] to interact with the Lorax!"

func _on_lorax_area_exited(body: Node2D) -> void:
	"""Called when player exits the Lorax interaction area."""
	if body == player:
		is_near_lorax = false
		$InteractionLabel.text = "Walk up close to the Lorax!"

func _input(event: InputEvent) -> void:
	"""Handle input events."""
	if not is_near_lorax:
		return
		
	# press E to load chat
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if chat_instance == null:
			_load_chat_interface()
			await get_tree().process_frame

		chat_instance.show()
		if chat_instance.has_method("open_chat"):
			chat_instance.open_chat()

		print("[LEVEL] Chat opened")
		
func _on_player_granted_access() -> void:
	_switch_music($Music/Success)
	chat_instance.hide()
	$InteractionLabel.text = "Congrats! Enter the forest by clicking on the storybook above!"
	level_select.show()
