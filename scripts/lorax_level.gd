extends Node2D

## Lorax Level Script
## Manages the game level, interactions, and chat interface

@onready var lorax: Area2D = $Interactables/LoraxArea
@onready var player: CharacterBody2D = $Player

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
	chat_instance.hide()
	$InteractionLabel.text = "Congrats! Enter the forest by clicking on the storybook above!"
	level_select.show()
