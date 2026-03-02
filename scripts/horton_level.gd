extends Control

## Horton Level Controller
## Manages the three-way interaction: Player ↔ Horton ↔ Baron Von Bitey

@onready var horton: Area2D = $Node2D/Horton
@onready var player: CharacterBody2D = $Node2D/Player
@onready var baron: Area2D = $Node2D/Baron

@onready var current_music: AudioStreamPlayer = null

# Interaction state
var is_near_horton: bool = false
var chat_instance: Control = null
var level_select: Control = null
var camera: Camera2D = null

func _ready() -> void:
	GameState.enable_movement()

	# Connect Horton area interaction
	if horton:
		horton.body_entered.connect(_on_horton_area_entered)
		horton.body_exited.connect(_on_horton_area_exited)

	# Camera setup
	camera = $Node2D/Player/Camera2D
	camera.limit_left  = -1280
	camera.limit_right =  1280
	camera.limit_top   =  0
	camera.limit_bottom = 720

	# Level selector (hidden until level is complete)
	level_select = GameState.load_top_scene("res://scenes/LevelSelector.tscn")
	level_select.hide()
	
	_switch_music($Music/Default)

	# Start Horton's entrance, then Baron's entrance
	$Node2D.horton_enter()
	await get_tree().create_timer(2.0).timeout
	$Node2D.baron_enter()
	
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
	"""Load and configure the three-way chat interface."""
	chat_instance = GameState.load_top_scene("res://scenes/HortonChat.tscn")
	chat_instance.hide()

	# Pass the Node2D sprites reference so chat can trigger animations
	if chat_instance.has_method("set_sprites_node"):
		chat_instance.set_sprites_node($Node2D)

	# Connect outcome signals
	chat_instance.horton_trusts_player.connect(_on_horton_trusts_player)
	chat_instance.baron_wins.connect(_on_baron_wins)
	chat_instance.whos_lost.connect(_on_whos_lost)
	print("[LEVEL] Chat interface loaded and signals connected.")

func _input(event: InputEvent) -> void:
	if not is_near_horton:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if chat_instance == null:
			_load_chat_interface()
			await get_tree().process_frame
		chat_instance.show()
		if chat_instance.has_method("open_chat"):
			chat_instance.open_chat()
		print("[LEVEL] Chat opened")

func _on_horton_area_entered(body: Node2D) -> void:
	if body == player:
		is_near_horton = true
		$InteractionLabel.text = "Press [E] to talk with Horton (and keep an eye on the Baron!)"

func _on_horton_area_exited(body: Node2D) -> void:
	if body == player:
		is_near_horton = false
		$InteractionLabel.text = "Walk up close to Horton the Elephant!"

# ---------------------------------------------------------------------------
# Outcome handlers
# ---------------------------------------------------------------------------

func _on_horton_trusts_player() -> void:
	"""WIN: Whoville saved, Baron defeated."""
	print("[HortonLevel] WIN! Horton's faithful. The Whos are safe!")
	if chat_instance:
		await get_tree().create_timer(3.5).timeout
		chat_instance.hide()
	$InteractionLabel.text = "The Whos are safe! An elephant's faithful, one hundred percent. Open the storybook above to continue..."
	level_select.show()

func _on_baron_wins() -> void:
	"""FAIL 1: Baron took the clover."""
	print("[HortonLevel] FAIL 1 — Baron took the clover!")
	if chat_instance:
		await get_tree().create_timer(4.0).timeout
		chat_instance.hide()
	$InteractionLabel.text = "Baron Von Bitey has taken the clover... The Whos are in terrible danger. Try again."

func _on_whos_lost() -> void:
	"""FAIL 2: Whos were lost without the player's help."""
	print("[HortonLevel] FAIL 2 — The Whos were lost.")
	if chat_instance:
		await get_tree().create_timer(4.0).timeout
		chat_instance.hide()
	$InteractionLabel.text = "The Whos needed your help, and the crisis was too great. The clover is safe... but Whoville is lost. Try again."
