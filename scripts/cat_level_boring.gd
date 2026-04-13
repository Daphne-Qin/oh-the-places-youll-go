extends Control

## Cat Level — Boring Path (baron_has_clover = true)
## Cat has drunk the Mischief Minestrone and is agreeable / soup-compliant.
## Baron walks in from offscreen with the clover and his job application.
## Player must wake the Cat up via: chaos argument, Lorax lie callback, or compliance mirror.

@onready var player: CharacterBody2D = $Node2D/Player
@onready var cat: Area2D = $Node2D/Cat
@onready var baron: Area2D = $Node2D/Baron
@onready var current_music: AudioStreamPlayer = null

var is_near_cat: bool = false
var level_complete: bool = false
var chat_instance: Control = null
var level_select: Control = null

func _ready() -> void:
	GameState.enable_movement()

	# Cat has had the soup — play soup_drink animation, then settle into idle
	cat.soup_drink()

	_switch_music($Music/Default)

	$InteractionLabel.text = "The Cat in the Hat seems... different today."

	# Camera (single screen)
	var camera = $Node2D/Player/Camera2D
	camera.limit_left   = 0
	camera.limit_right  = 1280
	camera.limit_top    = 0
	camera.limit_bottom = 720

	# Connect Cat area signals for E-key interaction
	cat.body_entered.connect(_on_cat_area_entered)
	cat.body_exited.connect(_on_cat_area_exited)

	# Level selector (hidden until win/fail)
	level_select = GameState.load_top_scene("res://scenes/LevelSelector.tscn")
	level_select.hide()

	# Walk Baron in from the right after a short delay
	await get_tree().create_timer(1.5).timeout
	_baron_walk_in()

func _baron_walk_in() -> void:
	if not is_instance_valid(baron):
		return
	baron.walk()
	baron.flip_h(true)   # facing left (walking toward center)
	var target_x = 980.0
	var distance = baron.global_position.x - target_x
	var duration = distance / 90.0   # ~90 px/s
	var tween = create_tween()
	tween.tween_property(baron, "global_position:x", target_x, max(0.1, duration))
	await tween.finished
	if is_instance_valid(baron):
		baron.idle_clover()
		baron.flip_h(false)
	$InteractionLabel.text = "Baron Von Bitey has arrived with the clover! Walk up to the Cat."

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
			$InteractionLabel.text = "The Cat tore up the job application. Open the storybook above to continue!"

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
		print("[CAT_LEVEL_BORING] Chat opened")

func _load_chat_interface() -> void:
	chat_instance = GameState.load_top_scene("res://scenes/CatChatBoring.tscn")
	chat_instance.hide()
	if chat_instance.has_signal("cat_adventure_begins"):
		chat_instance.cat_adventure_begins.connect(_on_cat_adventure_begins)
	if chat_instance.has_signal("cat_bored_out"):
		chat_instance.cat_bored_out.connect(_on_cat_bored_out)

func _on_cat_adventure_begins() -> void:
	GameState.set_can_move(true)
	GameState.complete_level("cat")
	level_complete = true
	if has_node("Music/Success"):
		_switch_music($Music/Success)
	if is_instance_valid(cat):
		cat.idle()
	if chat_instance:
		await get_tree().create_timer(3.0).timeout
		chat_instance.hide()
	print("[CAT_LEVEL_BORING] WIN — transitioning to EndSceneSuccess")
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/EndSceneSuccess.tscn")

func _on_cat_bored_out() -> void:
	if chat_instance:
		chat_instance.hide()
	print("[CAT_LEVEL_BORING] FAIL — Baron closed the deal — transitioning to EndSceneFailure")
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/EndSceneFailure.tscn")

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
