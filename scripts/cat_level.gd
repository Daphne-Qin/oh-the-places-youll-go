extends Control

## Cat in the Hat Level Controller
## Player talks to the Cat and gets recruited for the next adventure

@onready var player: CharacterBody2D = $Node2D/Player
@onready var cat: Area2D = $Node2D/Cat
@onready var current_music: AudioStreamPlayer = null
@onready var level_complete = false

var is_near_cat: bool = false
var chat_instance: Control = null
var level_select: Control = null

func _ready() -> void:
	GameState.enable_movement()
	
	cat.idle()
	
	_switch_music($Music/Default)

	# Fix InteractionLabel — anchor to bottom center
	var label = $InteractionLabel
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
		if not level_complete:
			$InteractionLabel.text = "Walk up to the Cat in the Hat!"
		else:
			$InteractionLabel.text = "The adventure begins! Open the storybook above to continue!"

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
	if chat_instance.has_signal("cat_bored_out"):
		chat_instance.cat_bored_out.connect(_on_cat_bored_out)
		print("[CAT_LEVEL] Connected cat_bored_out signal")

func _on_cat_adventure_begins() -> void:
	GameState.set_can_move(true)
	GameState.complete_level("cat")
	chat_instance.hide()
	$InteractionLabel.text = "The adventure begins! Open the storybook above to continue!"
	level_select.show()
	print("[CAT_LEVEL] WIN — adventure begins!")

func _on_cat_bored_out() -> void:
	GameState.enable_movement()
	if chat_instance:
		chat_instance.hide()
	$InteractionLabel.text = "The Cat has dismissed you. The storybook can take you somewhere else..."
	level_select.show()
	print("[CAT_LEVEL] FAIL — opening level select for retry.")

# ---------------------------------------------------------------------------
# Music crossfade
# ---------------------------------------------------------------------------
func _switch_music(new_music: AudioStreamPlayer) -> void:
	if new_music == current_music:
		return
	var fade_time = 1.0
	var tween = create_tween()
	if current_music and current_music.playing:
		tween.tween_property(current_music, "volume_db", -40.0, fade_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
	if current_music and current_music != new_music:
		current_music.stop()
	current_music = new_music
	current_music.volume_db = 0.0
	current_music.play()
