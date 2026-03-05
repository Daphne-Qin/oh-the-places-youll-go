extends Control

## Cat in the Hat Level Controller
## Player talks to the Cat and gets recruited for the next adventure

@onready var player: CharacterBody2D = $Node2D/Player
@onready var cat: Area2D = $Node2D/Cat

var is_near_cat: bool = false
var chat_instance: Control = null
var level_select: Control = null

func _ready() -> void:
	GameState.enable_movement()

	# Fix InteractionLabel — anchor to bottom center
	var label = $InteractionLabel
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -50
	label.offset_bottom = 0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.text = "Walk up to the Cat in the Hat!"

	# Camera limits (single screen)
	var camera = $Node2D/Player/Camera2D
	camera.limit_left = 0
	camera.limit_right = 1280
	camera.limit_top = 0
	camera.limit_bottom = 720

	# Connect Cat area signals
	cat.body_entered.connect(_on_cat_area_entered)
	cat.body_exited.connect(_on_cat_area_exited)

	# Level selector (hidden until win)
	level_select = GameState.load_top_scene("res://scenes/LevelSelector.tscn")
	level_select.hide()

func _on_cat_area_entered(body: Node2D) -> void:
	if body == player:
		is_near_cat = true
		$InteractionLabel.text = "Press [E] to talk to the Cat in the Hat!"

func _on_cat_area_exited(body: Node2D) -> void:
	if body == player:
		is_near_cat = false
		$InteractionLabel.text = "Walk up to the Cat in the Hat!"

func _input(event: InputEvent) -> void:
	if not is_near_cat:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if chat_instance == null:
			_load_chat_interface()
			await get_tree().process_frame
		chat_instance.show()
		if chat_instance.has_method("open_chat"):
			chat_instance.open_chat()
		print("[CAT_LEVEL] Chat opened")

func _load_chat_interface() -> void:
	chat_instance = GameState.load_top_scene("res://scenes/CatChat.tscn")
	chat_instance.hide()
	if chat_instance.has_signal("cat_adventure_begins"):
		chat_instance.cat_adventure_begins.connect(_on_cat_adventure_begins)
		print("[CAT_LEVEL] Connected cat_adventure_begins signal")

func _on_cat_adventure_begins() -> void:
	GameState.complete_level("cat")
	chat_instance.hide()
	$InteractionLabel.text = "The adventure begins! Open the storybook above to continue!"
	level_select.show()
	print("[CAT_LEVEL] WIN — adventure begins!")
