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
	
	# Connect Lorax area signals
	if lorax_area:
		lorax_area.body_entered.connect(_on_lorax_area_entered)
		lorax_area.body_exited.connect(_on_lorax_area_exited)

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
		$InteractionLabel.text = "Press [E] to interact with the Lorax!"
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
		$InteractionLabel.text = "Walk up close to the Lorax!"
		if interaction_prompt:
			# Animate prompt disappearance
			var tween = create_tween()
			tween.tween_property(interaction_prompt, "modulate:a", 0.0, 0.2)
			await tween.finished
			interaction_prompt.visible = false

func _input(event: InputEvent) -> void:
	if not is_near_lorax:
		return
		
	# press E to load chat
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if chat_instance == null:
			_load_chat_interface()
			await get_tree().process_frame

		chat_instance.visible = true
		if chat_instance.has_method("open_chat"):
			chat_instance.open_chat()

		print("[LEVEL] Chat opened")
