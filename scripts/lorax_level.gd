extends Node2D

## Lorax Level Script
## Manages the game level, interactions, and chat interface

@onready var lorax_area: Area2D = $Interactables/LoraxArea
@onready var player: CharacterBody2D = $Player

# Interaction prompt UI
var interaction_prompt: Label
var is_near_lorax: bool = false
var chat_instance: Control = null

func _ready() -> void:
	"""Initialize the level."""
	# Create interaction prompt
	_create_interaction_prompt()
	
	# Connect Lorax area signals
	if lorax_area:
		lorax_area.body_entered.connect(_on_lorax_area_entered)
		lorax_area.body_exited.connect(_on_lorax_area_exited)
	
	# Load and add chat interface
	_load_chat_interface()
	
	# Open chat automatically when level starts
	await get_tree().create_timer(1.0).timeout  # Wait 1 second for everything to initialize
	if chat_instance:
		print("[LEVEL] Opening chat automatically...")
		chat_instance.open_chat()
		print("[LEVEL] Chat opened. Visible: ", chat_instance.visible, " Is open: ", chat_instance.is_open)
	else:
		print("[LEVEL] ERROR: chat_instance is null!")
	
	print("Lorax Level loaded - Chat interface ready")

func _create_interaction_prompt() -> void:
	"""Create a UI prompt that appears when near the Lorax."""
	interaction_prompt = Label.new()
	interaction_prompt.text = "Press [E] to talk with the Lorax"
	interaction_prompt.add_theme_color_override("font_color", Color(0.9, 0.9, 0.2, 1))
	interaction_prompt.add_theme_font_size_override("font_size", 24)
	interaction_prompt.add_theme_constant_override("outline_size", 4)
	interaction_prompt.add_theme_color_override("font_outline_color", Color(0.2, 0.4, 0.1, 1))
	interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Add to a CanvasLayer so it's always on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "UILayer"
	add_child(canvas_layer)
	
	var prompt_container = Control.new()
	prompt_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(prompt_container)
	
	interaction_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	interaction_prompt.position.y = 100
	interaction_prompt.visible = false
	prompt_container.add_child(interaction_prompt)

func _load_chat_interface() -> void:
	"""Load and add the chat interface to the scene."""
	var chat_scene = preload("res://scenes/LoraxChat.tscn")
	chat_instance = chat_scene.instantiate()
	
	# Add to a CanvasLayer so it's always on top
	var ui_layer = get_node_or_null("UILayer")
	if not ui_layer:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UILayer"
		add_child(ui_layer)
	
	ui_layer.add_child(chat_instance)
	chat_instance.visible = false

func _on_lorax_area_entered(body: Node2D) -> void:
	"""Called when player enters the Lorax interaction area."""
	if body == player:
		is_near_lorax = true
		if interaction_prompt:
			interaction_prompt.visible = true
			# Animate prompt appearance
			var tween = create_tween()
			interaction_prompt.modulate.a = 0.0
			tween.tween_property(interaction_prompt, "modulate:a", 1.0, 0.3)

func _on_lorax_area_exited(body: Node2D) -> void:
	"""Called when player exits the Lorax interaction area."""
	if body == player:
		is_near_lorax = false
		if interaction_prompt:
			# Animate prompt disappearance
			var tween = create_tween()
			tween.tween_property(interaction_prompt, "modulate:a", 0.0, 0.2)
			await tween.finished
			interaction_prompt.visible = false

func _input(event: InputEvent) -> void:
	"""Handle input for opening chat."""
	if event.is_action_pressed("ui_select") or (event is InputEventKey and event.keycode == KEY_E and event.pressed):
		if is_near_lorax and chat_instance and not chat_instance.is_open:
			_open_chat()

func _open_chat() -> void:
	"""Open the chat interface."""
	if chat_instance:
		chat_instance.open_chat()
		# Hide interaction prompt when chat opens
		if interaction_prompt:
			interaction_prompt.visible = false
