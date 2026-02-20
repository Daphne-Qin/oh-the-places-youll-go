extends Control

## Horton Level Controller
## Manages player interaction with Horton the anxious elephant

@onready var horton: Area2D = $Node2D/Horton
@onready var player: CharacterBody2D = $Node2D/Player

# Interaction prompt UI
var is_near_horton: bool = false
var chat_instance: Control = null
var level_select: Control = null
var camera: Camera2D = null

func _ready() -> void:
	# Enable player movement when level starts
	GameState.enable_movement()

	# Connect to Horton's Area2D for interaction detection
	if horton:
		horton.body_entered.connect(_on_horton_area_entered)
		horton.body_exited.connect(_on_horton_area_exited)
	
	# set camera
	camera = $Node2D/Player/Camera2D
	camera.limit_left = -1280
	camera.limit_right = 1280
	camera.limit_top = 0
	camera.limit_bottom = 720

	# level menu
	level_select = GameState.load_top_scene("res://scenes/LevelSelector.tscn")
	level_select.hide()

	# Start Horton's entrance animation
	$Node2D.horton_enter()

func _load_chat_interface() -> void:
	"""Load and add the chat interface to the scene."""
	chat_instance = GameState.load_top_scene("res://scenes/HortonChat.tscn")
	chat_instance.hide()
	
	# level completed signal
	if chat_instance.has_signal("horton_trusts_player"):
		chat_instance.horton_trusts_player.connect(_on_horton_trusts_player)
		print("[LEVEL] Connected player_granted_access signal")

func _input(event: InputEvent) -> void:
	"""Handle input events."""
	if not is_near_horton:
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

func _on_horton_area_entered(body: Node2D) -> void:
	"""Called when player enters Horton's interaction area."""
	if body == player:
		is_near_horton = true
		$InteractionLabel.text = "Press [E] to interact with Horton! (He's very anxious...)"

func _on_horton_area_exited(body: Node2D) -> void:
	"""Called when player exits Horton's interaction area."""
	if body == player:
		is_near_horton = false
		$InteractionLabel.text = "Walk up close to Horton the Elephant!"

func _on_horton_trusts_player() -> void:
	"""Called when Horton finally trusts the player."""
	print("[HortonLevel] SUCCESS! Horton trusts the player!")
	chat_instance.hide()
	$InteractionLabel.text = "Congrats! Continue to the depths of the forest by clicking the storybook above..."

func _on_horton_ran_away() -> void:
	"""Called when Horton's anxiety overwhelms him and he runs away."""
	print("[HortonLevel] FAILURE! Horton ran away!")
	chat_instance.hide()
