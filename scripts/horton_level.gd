extends Control

## Horton Level Controller
## Manages player interaction with Horton the anxious elephant

# Chat system
var horton_chat_scene = null  # Will be loaded at runtime
var horton_chat_instance = null

# Interaction tracking
var player_in_range: bool = false
var chat_is_open: bool = false

# UI elements
var interaction_label: Label

var camera: Camera2D = null

func _ready() -> void:
	# Enable player movement when level starts
	GameState.enable_movement()
	
	# set camera
	camera = $Node2D/Player/Camera2D
	camera.limit_left = -1280
	camera.limit_right = 1280
	camera.limit_top = 0
	camera.limit_bottom = 720

	# Load the HortonChat scene at runtime
	horton_chat_scene = load("res://scenes/HortonChat.tscn")
	if not horton_chat_scene:
		print("[HortonLevel] ERROR: Failed to load HortonChat.tscn!")
	else:
		print("[HortonLevel] HortonChat scene loaded successfully")
	horton_chat_instance = horton_chat_scene.instantiate()
	var ui_layer = get_node_or_null("UILayer")
	if not ui_layer:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UILayer"
		add_child(ui_layer)
	
	ui_layer.add_child(horton_chat_instance)
	horton_chat_instance.hide()

	# Start Horton's entrance animation
	$Node2D.horton_enter()

	# Create interaction label
	_create_interaction_label()

	# Connect to Horton's Area2D for interaction detection
	if $Node2D/Horton:
		$Node2D/Horton.body_entered.connect(_on_player_entered_horton_area)
		$Node2D/Horton.body_exited.connect(_on_player_exited_horton_area)

	print("[HortonLevel] Level ready, interaction enabled")
	print("[HortonLevel] Player can move: ", GameState.can_move)

func _create_interaction_label() -> void:
	"""Create the 'Press E to interact' label."""
	interaction_label = Label.new()
	interaction_label.text = "Press [E] to talk to Horton! (He's very anxious...)"
	interaction_label.visible = false
	interaction_label.position = Vector2(400, 50)  # Top-center area

	# Style the label
	interaction_label.add_theme_font_size_override("font_size", 20)
	interaction_label.add_theme_color_override("font_color", Color(1, 1, 1))
	interaction_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	interaction_label.add_theme_constant_override("outline_size", 4)

	add_child(interaction_label)

func _process(_delta: float) -> void:
	# Check for interaction input when player is in range
	if player_in_range and not chat_is_open:
		# Check for E key (using Input.is_action_just_pressed for proper single-press detection)
		if Input.is_action_just_pressed("ui_accept"):
			print("[HortonLevel] Enter/Space pressed!")
			_open_horton_chat()

func _input(event: InputEvent) -> void:
	"""Handle input events."""
	# Handle E key press for interaction
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and player_in_range and not chat_is_open:
			print("[HortonLevel] E key pressed!")
			_open_horton_chat()

	# Handle escape to close chat
	if event.is_action_pressed("ui_cancel") and chat_is_open:
		if horton_chat_instance:
			horton_chat_instance.close_chat()
			chat_is_open = false
			# Show interaction label again if player still in range
			if player_in_range and interaction_label:
				interaction_label.visible = true

func _on_player_entered_horton_area(body: Node2D) -> void:
	"""Called when player enters Horton's interaction area."""
	print("[HortonLevel] body_entered signal fired! Body: ", body.name)
	if body.name == "Player":
		print("[HortonLevel] Player entered Horton area!")
		player_in_range = true
		if interaction_label:
			interaction_label.visible = true
			print("[HortonLevel] Interaction label shown")

func _on_player_exited_horton_area(body: Node2D) -> void:
	"""Called when player exits Horton's interaction area."""
	print("[HortonLevel] body_exited signal fired! Body: ", body.name)
	if body.name == "Player":
		print("[HortonLevel] Player exited Horton area")
		player_in_range = false
		if interaction_label:
			interaction_label.visible = false
			print("[HortonLevel] Interaction label hidden")

func _open_horton_chat() -> void:
	"""Open the Horton chat interface."""
	if chat_is_open:
		print("[HortonLevel] Chat already open, skipping...")
		return

	print("[HortonLevel] _open_horton_chat() called!")

	# Hide interaction label
	if interaction_label:
		interaction_label.visible = false
		print("[HortonLevel] Interaction label hidden")

	# Check if scene is loaded
	if not horton_chat_scene:
		print("[HortonLevel] ERROR: horton_chat_scene is null! Can't open chat.")
		return

	# Instantiate chat if needed
	if not horton_chat_instance:
		print("[HortonLevel] Creating new HortonChat instance...")
		horton_chat_instance = horton_chat_scene.instantiate()

		if not horton_chat_instance:
			print("[HortonLevel] ERROR: Failed to instantiate HortonChat!")
			return

		print("[HortonLevel] Adding HortonChat to scene tree...")
		add_child(horton_chat_instance)

		# Connect to chat signals
		print("[HortonLevel] Connecting signals...")
		horton_chat_instance.horton_trusts_player.connect(_on_horton_trusts_player)
		horton_chat_instance.horton_ran_away.connect(_on_horton_ran_away)

	# Open the chat
	print("[HortonLevel] Calling horton_chat_instance.open_chat()...")
	horton_chat_instance.open_chat()
	chat_is_open = true
	print("[HortonLevel] Chat should be open now!")

func _on_horton_trusts_player() -> void:
	"""Called when Horton finally trusts the player."""
	print("[HortonLevel] SUCCESS! Horton trusts the player!")
	# Could trigger level completion animation here
	# GameState.complete_level("horton") is already called in horton_chat.gd

func _on_horton_ran_away() -> void:
	"""Called when Horton's anxiety overwhelms him and he runs away."""
	print("[HortonLevel] FAILURE! Horton ran away!")
	chat_is_open = false
	# Maybe show a "Try again?" message or return to level select
